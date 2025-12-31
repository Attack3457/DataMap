// 📁 File: Models/Project.swift
// 🎯 SWIFTDATA PROJECT MODEL FOR ORGANIZING SCANNED DIRECTORIES

import Foundation
import SwiftData

@Model
public final class Project: Identifiable {
    @Attribute(.unique) public var id: UUID
    var name: String
    var rootPath: String
    var createdAt: Date
    var lastScannedAt: Date?
    var isActive: Bool
    
    // Project metadata
    var projectDescription: String
    var tags: [String] = []
    var colorHex: String = "#007AFF"
    
    // Scan configuration
    var maxDepth: Int = 5
    var excludeHiddenFiles: Bool = true
    var allowedExtensions: [String] = []
    
    // Statistics
    var totalNodes: Int = 0
    var totalFiles: Int = 0
    var totalDirectories: Int = 0
    var totalSize: Int64 = 0
    
    // Relationships - UPDATED FOR GRAPH-BASED NODES
    @Relationship(deleteRule: .cascade) var nodes: [FileNode] = []
    
    // Computed properties
    var rootURL: URL {
        URL(fileURLWithPath: rootPath)
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var formattedLastScanned: String {
        guard let lastScannedAt = lastScannedAt else {
            return "Never scanned"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastScannedAt)
    }
    
    // Additional computed properties for compatibility
    var nodeCount: Int {
        return totalNodes
    }
    
    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        name: String,
        rootPath: String,
        projectDescription: String = "",
        createdAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.projectDescription = projectDescription
        self.createdAt = createdAt
        self.isActive = isActive
    }
    
    // MARK: - Factory Methods
    static func createFromDirectory(at url: URL, name: String? = nil) -> Project {
        let projectName = name ?? url.lastPathComponent
        return Project(
            name: projectName,
            rootPath: url.path,
            projectDescription: "Project created from \(url.path)"
        )
    }
    
    // MARK: - Project Management
    func updateStatistics() {
        totalNodes = nodes.count
        totalFiles = nodes.filter { !$0.isDirectory }.count
        totalDirectories = nodes.filter { $0.isDirectory }.count
        totalSize = nodes.reduce(0) { $0 + $1.size }
    }
    
    func markAsScanned() {
        lastScannedAt = Date()
        updateStatistics()
    }
    
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    func setColor(_ colorHex: String) {
        self.colorHex = colorHex
    }
    
    // MARK: - Node Management
    func addNode(_ node: FileNode) {
        if !nodes.contains(where: { $0.id == node.id }) {
            nodes.append(node)
            node.project = self
            updateStatistics()
        }
    }
    
    func removeNode(_ node: FileNode) {
        nodes.removeAll { $0.id == node.id }
        if node.project?.id == self.id {
            node.project = nil
        }
        updateStatistics()
    }
    
    func clearNodes() {
        for node in nodes {
            node.project = nil
        }
        nodes.removeAll()
        updateStatistics()
    }
    
    // MARK: - Query Methods
    var rootNodes: [FileNode] {
        return nodes.filter { $0.parent == nil }
    }
    
    func nodesWithTag(_ tag: String) -> [FileNode] {
        return nodes.filter { $0.tags.contains(tag) }
    }
    
    func bookmarkedNodes() -> [FileNode] {
        return nodes.filter { $0.isBookmarked }
    }
    
    // MARK: - Search
    func searchNodes(query: String) -> [FileNode] {
        let lowercaseQuery = query.lowercased()
        return nodes.filter { node in
            node.name.lowercased().contains(lowercaseQuery) ||
            node.path.lowercased().contains(lowercaseQuery) ||
            node.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
}

// MARK: - Preview Support
extension Project {
    static var previewProject: Project {
        let project = Project(
            name: "Sample Project",
            rootPath: "/Users/test/Documents",
            projectDescription: "A sample project for preview"
        )
        
        project.totalNodes = 150
        project.totalFiles = 120
        project.totalDirectories = 30
        project.totalSize = 50 * 1024 * 1024 // 50MB
        project.lastScannedAt = Date()
        
        return project
    }
    
    static var previewProjects: [Project] {
        return [
            Project(name: "Documents", rootPath: "/Users/test/Documents"),
            Project(name: "Downloads", rootPath: "/Users/test/Downloads"),
            Project(name: "Pictures", rootPath: "/Users/test/Pictures"),
            Project(name: "Code Projects", rootPath: "/Users/test/Code")
        ]
    }
}