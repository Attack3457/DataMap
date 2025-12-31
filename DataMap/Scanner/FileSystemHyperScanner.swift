// 📁 File: Scanner/FileSystemHyperScanner.swift
// 🎯 ACTOR-BASED ASYNC FILE SYSTEM SCANNER

import Foundation
import CoreLocation

// MARK: - File System Scanner Protocol
public protocol FileSystemScannerProtocol {
    func scanDirectory(at path: String) async throws -> FileNode
    func scanDirectoryShallow(at path: String) async throws -> [FileNode]
}

// MARK: - File System Hyper Scanner
public actor FileSystemHyperScanner: FileSystemScannerProtocol {
    
    // MARK: - Configuration
    public struct ScanConfiguration {
        var maxDepth: Int = 5
        var maxFilesPerDirectory: Int = 1000
        var excludeHiddenFiles: Bool = true
        var excludeSystemDirectories: Bool = true
        var allowedExtensions: [String]? = nil
        var maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
        
        public static let `default` = ScanConfiguration()
    }
    
    // MARK: - Properties
    private let coordinateEngine: CoordinateEngine
    private let configuration: ScanConfiguration
    private let fileManager = FileManager.default
    private var scanProgress: Double = 0.0
    private var isCancelled = false
    
    // MARK: - Initializer
    public init(
        coordinateEngine: CoordinateEngine,
        configuration: ScanConfiguration = .default
    ) {
        self.coordinateEngine = coordinateEngine
        self.configuration = configuration
    }
    
    // MARK: - Public API
    
    /// Main directory scanning function
    public func scanDirectory(at path: String) async throws -> FileNode {
        isCancelled = false
        scanProgress = 0.0
        
        guard fileManager.fileExists(atPath: path) else {
            throw GeoMapperError.fileSystemAccess("Directory does not exist: \(path)")
        }
        
        let url = URL(fileURLWithPath: path)
        let rootItem = try FileSystemItem.create(from: url)
        
        return try await scanDirectoryRecursive(
            item: rootItem,
            depth: 0,
            parentNode: nil
        )
    }
    
    /// Shallow scan (one level only)
    public func scanDirectoryShallow(at path: String) async throws -> [FileNode] {
        guard fileManager.fileExists(atPath: path) else {
            throw GeoMapperError.fileSystemAccess("Directory does not exist: \(path)")
        }
        
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        var nodes: [FileNode] = []
        
        for item in contents.prefix(configuration.maxFilesPerDirectory) {
            if isCancelled { break }
            
            let itemPath = (path as NSString).appendingPathComponent(item)
            let itemURL = URL(fileURLWithPath: itemPath)
            
            do {
                let fileItem = try FileSystemItem.create(from: itemURL)
                
                if fileItem.shouldBeExcluded(configuration: configuration) {
                    continue
                }
                
                let node = FileNode.createFromFileItem(
                    fileItem,
                    parentNode: nil
                )
                nodes.append(node)
            } catch {
                // Skip items that can't be read
                continue
            }
        }
        
        return nodes.sorted { $0.isDirectory && !$1.isDirectory }
    }
    
    /// Cancel ongoing scan
    public func cancelScan() {
        isCancelled = true
    }
    
    /// Get current scan progress
    public func getScanProgress() -> Double {
        return scanProgress
    }
    
    // MARK: - Private Methods
    
    private func scanDirectoryRecursive(
        item: FileSystemItem,
        depth: Int,
        parentNode: FileNode?
    ) async throws -> FileNode {
        
        // Create FileNode for this item
        let node = FileNode.createFromFileItem(
            item,
            parentNode: parentNode
        )
        
        // Stop if max depth reached or not a directory
        if depth >= configuration.maxDepth || !item.isDirectory {
            return node
        }
        
        // Scan children
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: item.url.path)
            var children: [FileNode] = []
            
            for (index, itemName) in contents.enumerated() {
                if isCancelled { break }
                
                // Update progress
                scanProgress = Double(index) / Double(contents.count)
                
                let childURL = item.url.appendingPathComponent(itemName)
                
                do {
                    let childItem = try FileSystemItem.create(from: childURL)
                    
                    if childItem.shouldBeExcluded(configuration: configuration) {
                        continue
                    }
                    
                    if children.count >= configuration.maxFilesPerDirectory {
                        break
                    }
                    
                    let childNode: FileNode
                    
                    if childItem.isDirectory {
                        childNode = try await scanDirectoryRecursive(
                            item: childItem,
                            depth: depth + 1,
                            parentNode: node
                        )
                    } else {
                        childNode = FileNode.createFromFileItem(
                            childItem,
                            parentNode: node
                        )
                    }
                    
                    children.append(childNode)
                    node.addChild(childNode)
                    
                } catch {
                    // Skip items that can't be read
                    continue
                }
            }
            
            // Sort: directories first, then by name
            node.children = children.sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            
        } catch {
            // If we can't read directory contents, return empty directory node
            print("Warning: Could not read contents of \(item.url.path): \(error)")
        }
        
        return node
    }
}

// MARK: - Convenience Extensions
extension FileSystemHyperScanner {
    /// Quick scan of user's home directory
    public static func scanHomeDirectory() async throws -> FileNode {
        #if os(macOS)
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        #else
        let homeDir = NSHomeDirectory()
        #endif
        let engine = CoordinateEngine()
        let scanner = FileSystemHyperScanner(coordinateEngine: engine)
        return try await scanner.scanDirectory(at: homeDir)
    }
    
    /// Quick scan of Documents directory
    public static func scanDocumentsDirectory() async throws -> FileNode {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
        let engine = CoordinateEngine()
        let scanner = FileSystemHyperScanner(coordinateEngine: engine)
        return try await scanner.scanDirectory(at: documentsDir)
    }
    
    /// Scan directory and create project
    public static func scanDirectoryAsProject(
        at path: String,
        projectName: String? = nil
    ) async throws -> (project: Project, rootNode: FileNode) {
        let engine = CoordinateEngine()
        let scanner = FileSystemHyperScanner(coordinateEngine: engine)
        
        let rootNode = try await scanner.scanDirectory(at: path)
        let project = Project.createFromDirectory(
            at: URL(fileURLWithPath: path),
            name: projectName
        )
        
        // Add all nodes to project
        let allNodes = flattenNodes(rootNode)
        for node in allNodes {
            project.addNode(node)
        }
        
        project.markAsScanned()
        
        return (project, rootNode)
    }
    
    private static func flattenNodes(_ node: FileNode) -> [FileNode] {
        var result = [node]
        for child in node.children {
            result.append(contentsOf: flattenNodes(child))
        }
        return result
    }
}