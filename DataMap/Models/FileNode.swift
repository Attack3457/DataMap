// 📁 File: Models/FileNode.swift
// 🎯 GRAPH-BASED FILE NODE REPRESENTATION

import Foundation
import SwiftData
import simd

@Model
public final class FileNode: Identifiable, Hashable, Sendable {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var path: String
    public var nodeType: NodeType
    public var size: Int64
    
    // GRAPH POSITIONS (NO MORE GEOGRAPHIC COORDINATES!)
    public var graphX: Double = 0.5
    public var graphY: Double = 0.5
    public var velocityX: Double = 0.0
    public var velocityY: Double = 0.0
    
    // Metadata
    public var iconName: String = "folder"
    public var colorHex: String = "#007AFF"
    public var tags: [String] = []
    public var isBookmarked: Bool = false
    public var createdAt: Date
    public var modifiedAt: Date
    public var lastAccessed: Date = Date()
    
    // Hierarchy (graph edges olacak)
    @Relationship(deleteRule: .nullify) public var parent: FileNode?
    @Relationship(deleteRule: .cascade) public var children: [FileNode] = []
    @Relationship(inverse: \Project.nodes) public var project: Project?
    
    // Computed properties
    public var graphPosition: SIMD2<Double> {
        SIMD2<Double>(graphX, graphY)
    }
    
    public var isDirectory: Bool {
        nodeType == .directory
    }
    
    public var isFile: Bool {
        nodeType == .file
    }
    
    public var depth: Int {
        var current = parent
        var depth = 0
        while current != nil {
            depth += 1
            current = current?.parent
        }
        return depth
    }
    
    public var fileURL: URL {
        URL(fileURLWithPath: path)
    }
    
    // MARK: - Node Types
    public enum NodeType: Int, Codable {
        case directory = 0
        case file = 1
        case symbolicLink = 2
        case unknown = 3
        
        public var iconName: String {
            switch self {
            case .directory: return "folder"
            case .file: return "doc"
            case .symbolicLink: return "link"
            case .unknown: return "questionmark"
            }
        }
        
        public var defaultColor: String {
            switch self {
            case .directory: return "#007AFF" // Blue
            case .file: return "#8E8E93" // Gray
            case .symbolicLink: return "#FF9500" // Orange
            case .unknown: return "#FF3B30" // Red
            }
        }
        
        public var systemImageName: String {
            switch self {
            case .directory: return "folder.fill"
            case .file: return "doc.fill"
            case .symbolicLink: return "link"
            case .unknown: return "questionmark.circle.fill"
            }
        }
    }
    
    // MARK: - Initializer
    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        nodeType: NodeType,
        size: Int64 = 0,
        graphPosition: SIMD2<Double> = SIMD2<Double>(0.5, 0.5),
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        parent: FileNode? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.nodeType = nodeType
        self.size = size
        self.graphX = graphPosition.x
        self.graphY = graphPosition.y
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.parent = parent
        self.iconName = nodeType.iconName
        self.colorHex = nodeType.defaultColor
    }
    
    // MARK: - Graph Methods
    public func updatePosition(_ newPosition: SIMD2<Double>) {
        self.graphX = newPosition.x
        self.graphY = newPosition.y
    }
    
    public func addForce(_ force: SIMD2<Double>) {
        self.velocityX += force.x
        self.velocityY += force.y
    }
    
    public func applyVelocity(damping: Double = 0.8) {
        self.graphX += velocityX
        self.graphY += velocityY
        
        // Apply damping
        self.velocityX *= damping
        self.velocityY *= damping
        
        // Keep within bounds
        self.graphX = max(0.0, min(1.0, self.graphX))
        self.graphY = max(0.0, min(1.0, self.graphY))
    }
    
    // MARK: - Factory Methods
    public static func createFromFileItem(
        _ item: FileSystemItem,
        parentNode: FileNode? = nil,
        project: Project? = nil
    ) -> FileNode {
        let node = FileNode(
            name: item.name,
            path: item.url.path,
            nodeType: item.isDirectory ? .directory : .file,
            size: item.size,
            createdAt: item.createdDate ?? Date(),
            modifiedAt: item.modifiedDate ?? Date(),
            parent: parentNode
        )
        
        node.project = project
        return node
    }
    
    // MARK: - Hashable Conformance
    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public nonisolated static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Helper Methods
    public func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }
    
    public func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedAt)
    }
    
    // MARK: - Hierarchy Methods
    public func addChild(_ child: FileNode) {
        if !children.contains(where: { $0.id == child.id }) {
            children.append(child)
            child.parent = self
        }
    }
    
    public func removeChild(_ child: FileNode) {
        children.removeAll { $0.id == child.id }
        if child.parent?.id == self.id {
            child.parent = nil
        }
    }
    
    public var fullPath: String {
        var components: [String] = [name]
        var current = parent
        while let parent = current {
            components.insert(parent.name, at: 0)
            current = parent.parent
        }
        return components.joined(separator: "/")
    }
    
    // MARK: - Color Management
    public func setColor(_ colorHex: String) {
        self.colorHex = colorHex
    }
    
    public func resetToDefaultColor() {
        self.colorHex = nodeType.defaultColor
    }
    
    // MARK: - File Extension Support
    public var fileExtension: String {
        return (path as NSString).pathExtension.lowercased()
    }
    
    public var systemImageName: String {
        if isDirectory {
            return "folder.fill"
        }
        
        switch fileExtension {
        case "swift": return "swift"
        case "txt", "md": return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif": return "photo.fill"
        case "mp3", "wav", "m4a": return "music.note"
        case "mp4", "mov", "avi": return "video.fill"
        case "pdf": return "doc.richtext.fill"
        case "zip", "rar", "7z": return "archivebox.fill"
        default: return "doc.fill"
        }
    }
    
    /// Total children count (recursive)
    public var totalChildrenCount: Int {
        return children.count + children.reduce(0) { $0 + $1.totalChildrenCount }
    }
    
    /// Calculate mass for force-directed layout
    public var layoutMass: Double {
        if isDirectory {
            return 2.0 + Double(children.count) * 0.1
        } else {
            return 1.0 + Double(size) / (1024 * 1024) // MB cinsinden
        }
    }
    
    /// Get all descendant nodes (recursive)
    public var allDescendants: [FileNode] {
        var descendants: [FileNode] = []
        for child in children {
            descendants.append(child)
            descendants.append(contentsOf: child.allDescendants)
        }
        return descendants
    }
    
    /// Get all ancestor nodes
    public var ancestors: [FileNode] {
        var ancestors: [FileNode] = []
        var current = parent
        while let parent = current {
            ancestors.append(parent)
            current = parent.parent
        }
        return ancestors
    }
}

// MARK: - Preview Support
extension FileNode {
    public static var previewDirectory: FileNode {
        FileNode(
            name: "Documents",
            path: "/Users/test/Documents",
            nodeType: .directory,
            graphPosition: SIMD2<Double>(0.5, 0.5)
        )
    }
    
    public static var previewFile: FileNode {
        FileNode(
            name: "Report.pdf",
            path: "/Users/test/Documents/Report.pdf",
            nodeType: .file,
            size: 1024 * 1024, // 1MB
            graphPosition: SIMD2<Double>(0.6, 0.4)
        )
    }
    
    public static var previewHierarchy: [FileNode] {
        let root = FileNode(
            name: "Root",
            path: "/",
            nodeType: .directory,
            graphPosition: SIMD2<Double>(0.5, 0.5)
        )
        
        let docs = FileNode(
            name: "Documents",
            path: "/Documents",
            nodeType: .directory,
            graphPosition: SIMD2<Double>(0.3, 0.3),
            parent: root
        )
        
        let images = FileNode(
            name: "Images",
            path: "/Images",
            nodeType: .directory,
            graphPosition: SIMD2<Double>(0.7, 0.3),
            parent: root
        )
        
        let file1 = FileNode(
            name: "Report.pdf",
            path: "/Documents/Report.pdf",
            nodeType: .file,
            size: 1024 * 1024,
            graphPosition: SIMD2<Double>(0.2, 0.1),
            parent: docs
        )
        
        let file2 = FileNode(
            name: "Photo.jpg",
            path: "/Images/Photo.jpg",
            nodeType: .file,
            size: 2 * 1024 * 1024,
            graphPosition: SIMD2<Double>(0.8, 0.1),
            parent: images
        )
        
        root.addChild(docs)
        root.addChild(images)
        docs.addChild(file1)
        images.addChild(file2)
        
        return [root, docs, images, file1, file2]
    }
}