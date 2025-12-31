// 📁 File: Scanner/FileSystemScanner.swift
// 🎯 ENHANCED FILE SYSTEM SCANNER WITH STATISTICS

import Foundation

// MARK: - Scan Statistics
public struct ScanStatistics: Codable, Sendable {
    public let totalFiles: Int
    public let totalFolders: Int
    public let totalSize: Int64
    public let scanDuration: TimeInterval
    public let memoryPeak: Int64
    public let errorsEncountered: Int
    
    public nonisolated init(
        totalFiles: Int,
        totalFolders: Int,
        totalSize: Int64,
        scanDuration: TimeInterval,
        memoryPeak: Int64,
        errorsEncountered: Int
    ) {
        self.totalFiles = totalFiles
        self.totalFolders = totalFolders
        self.totalSize = totalSize
        self.scanDuration = scanDuration
        self.memoryPeak = memoryPeak
        self.errorsEncountered = errorsEncountered
    }
    
    public var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    public var formattedDuration: String {
        return String(format: "%.2f seconds", scanDuration)
    }
    
    public var filesPerSecond: Double {
        guard scanDuration > 0 else { return 0 }
        return Double(totalFiles) / scanDuration
    }
}

// MARK: - File System Scanner
public actor FileSystemScanner {
    
    // MARK: - Configuration
    public struct Configuration {
        public var maxDepth: Int = 10
        public var maxFilesPerDirectory: Int = 10000
        public var excludeHiddenFiles: Bool = true
        public var excludeSystemDirectories: Bool = true
        public var allowedExtensions: Set<String>? = nil
        public var maxFileSize: Int64 = 1_073_741_824 // 1GB
        public var followSymlinks: Bool = false
        
        public static let `default` = Configuration()
    }
    
    // MARK: - Properties
    private let configuration: Configuration
    private let fileManager = FileManager.default
    private var isCancelled = false
    private var startTime: Date = Date()
    private var statistics = ScanStatistics(
        totalFiles: 0,
        totalFolders: 0,
        totalSize: 0,
        scanDuration: 0,
        memoryPeak: 0,
        errorsEncountered: 0
    )
    
    // MARK: - Initializer
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Scan a directory and return file items with statistics
    public func scan(
        rootURL: URL,
        progressHandler: @escaping (Double, Int) -> Void
    ) async throws -> ([FileSystemItem], ScanStatistics) {
        
        isCancelled = false
        startTime = Date()
        
        var allItems: [FileSystemItem] = []
        var totalFiles = 0
        var totalFolders = 0
        var totalSize: Int64 = 0
        var errorsEncountered = 0
        
        // Recursive scan function
        func scanRecursive(url: URL, depth: Int) async throws {
            guard !isCancelled && depth < configuration.maxDepth else { return }
            
            do {
                let item = try await createFileSystemItem(from: url)
                
                // Check if item should be excluded
                if shouldExcludeItem(item) {
                    return
                }
                
                allItems.append(item)
                
                if item.isDirectory {
                    totalFolders += 1
                    
                    // Scan directory contents
                    let contents = try fileManager.contentsOfDirectory(at: url, 
                                                                      includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                                                                      options: configuration.excludeHiddenFiles ? [.skipsHiddenFiles] : [])
                    
                    let limitedContents = Array(contents.prefix(configuration.maxFilesPerDirectory))
                    
                    for childURL in limitedContents {
                        if isCancelled { break }
                        try await scanRecursive(url: childURL, depth: depth + 1)
                    }
                } else {
                    totalFiles += 1
                    totalSize += item.size
                }
                
                // Update progress
                let progress = Double(allItems.count) / Double(max(allItems.count, 100))
                progressHandler(progress, allItems.count)
                
            } catch {
                errorsEncountered += 1
                print("Error scanning \(url.path): \(error)")
            }
        }
        
        // Start scanning
        try await scanRecursive(url: rootURL, depth: 0)
        
        // Calculate final statistics
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        let finalStatistics = ScanStatistics(
            totalFiles: totalFiles,
            totalFolders: totalFolders,
            totalSize: totalSize,
            scanDuration: duration,
            memoryPeak: getCurrentMemoryUsage(),
            errorsEncountered: errorsEncountered
        )
        
        return (allItems, finalStatistics)
    }
    
    /// Cancel the current scan operation
    public func cancel() {
        isCancelled = true
    }
    
    /// Check if scan is cancelled
    public func isScanCancelled() -> Bool {
        return isCancelled
    }
    
    // MARK: - Private Methods
    
    private func createFileSystemItem(from url: URL) async throws -> FileSystemItem {
        let fileManager = FileManager.default
        
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw ScanError.invalidURL("File does not exist: \(url.path)")
        }
        
        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        
        let name = url.lastPathComponent
        let isDirectory = (attributes[.type] as? FileAttributeType) == .typeDirectory
        let size = attributes[.size] as? Int64 ?? 0
        let createdDate = attributes[.creationDate] as? Date
        let modifiedDate = attributes[.modificationDate] as? Date
        let isHidden = name.hasPrefix(".")
        
        // Check if it's a symbolic link
        var isSymbolicLink = false
        if let fileType = attributes[.type] as? FileAttributeType {
            isSymbolicLink = fileType == .typeSymbolicLink
        }
        
        return FileSystemItem(
            url: url,
            name: name,
            isDirectory: isDirectory,
            size: size,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            isHidden: isHidden,
            isSymbolicLink: isSymbolicLink
        )
    }
    
    private func shouldExcludeItem(_ item: FileSystemItem) -> Bool {
        // Check hidden files
        if configuration.excludeHiddenFiles && item.isHidden {
            return true
        }
        
        // Check system directories
        if configuration.excludeSystemDirectories && item.isDirectory {
            let systemDirs = ["System", "Library", "Applications", "usr", "bin", "sbin", "var", "tmp", "private"]
            if systemDirs.contains(item.name) {
                return true
            }
        }
        
        // Check file size
        if !item.isDirectory && item.size > configuration.maxFileSize {
            return true
        }
        
        // Check allowed extensions
        if let allowedExtensions = configuration.allowedExtensions,
           !item.isDirectory && !allowedExtensions.isEmpty {
            let ext = (item.url.path as NSString).pathExtension.lowercased()
            return !allowedExtensions.contains(ext)
        }
        
        // Check symlinks
        if item.isSymbolicLink && !configuration.followSymlinks {
            return true
        }
        
        return false
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Convenience Extensions
extension FileSystemScanner {
    
    /// Quick scan of user's home directory
    public static func scanHomeDirectory() async throws -> ([FileSystemItem], ScanStatistics) {
        let homeURL = FileManager.default.urls(for: .userDirectory, in: .userDomainMask).first!
        let scanner = FileSystemScanner()
        return try await scanner.scan(rootURL: homeURL) { _, _ in }
    }
    
    /// Quick scan of Documents directory
    public static func scanDocumentsDirectory() async throws -> ([FileSystemItem], ScanStatistics) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let scanner = FileSystemScanner()
        return try await scanner.scan(rootURL: documentsURL) { _, _ in }
    }
    
    /// Scan with custom configuration
    public static func scan(
        url: URL,
        configuration: Configuration,
        progressHandler: @escaping (Double, Int) -> Void = { _, _ in }
    ) async throws -> ([FileSystemItem], ScanStatistics) {
        let scanner = FileSystemScanner(configuration: configuration)
        return try await scanner.scan(rootURL: url, progressHandler: progressHandler)
    }
}

// MARK: - Preview Support
extension FileSystemScanner {
    public static func previewScanner() -> FileSystemScanner {
        var config = Configuration.default
        config.maxDepth = 3
        config.maxFilesPerDirectory = 50
        return FileSystemScanner(configuration: config)
    }
}

// MARK: - Error Handling
extension FileSystemScanner {
    public enum ScanError: Error, LocalizedError {
        case invalidURL(String)
        case permissionDenied(String)
        case scanCancelled
        case memoryLimitExceeded
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL(let path):
                return "Invalid URL: \(path)"
            case .permissionDenied(let path):
                return "Permission denied for: \(path)"
            case .scanCancelled:
                return "Scan was cancelled"
            case .memoryLimitExceeded:
                return "Memory limit exceeded during scan"
            }
        }
    }
}