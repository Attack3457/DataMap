// 📁 File: Models/FileSystemItem.swift
// 🎯 FILE SYSTEM ITEM REPRESENTATION FOR SCANNING

import Foundation

// MARK: - FileSystemItem
public struct FileSystemItem: Identifiable, Sendable {
    public let id = UUID()
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public let createdDate: Date?
    public let modifiedDate: Date?
    public let isHidden: Bool
    public let isSymbolicLink: Bool
    
    // MARK: - Initializer
    nonisolated public init(
        url: URL,
        name: String,
        isDirectory: Bool,
        size: Int64 = 0,
        createdDate: Date? = nil,
        modifiedDate: Date? = nil,
        isHidden: Bool = false,
        isSymbolicLink: Bool = false
    ) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.isHidden = isHidden
        self.isSymbolicLink = isSymbolicLink
    }
    
    // MARK: - Factory Methods
    nonisolated public static func create(from url: URL) throws -> FileSystemItem {
        let fileManager = FileManager.default
        
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw GeoMapperError.fileSystemAccess("File does not exist: \(url.path)")
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
    
    // MARK: - Computed Properties
    nonisolated public var fileExtension: String {
        return url.pathExtension.lowercased()
    }
    
    nonisolated public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    nonisolated public var formattedModifiedDate: String {
        guard let modifiedDate = modifiedDate else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
    
    nonisolated public var systemImageName: String {
        if isDirectory {
            return "folder.fill"
        }
        
        if isSymbolicLink {
            return "link"
        }
        
        switch fileExtension {
        case "swift": return "swift"
        case "txt", "md": return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif": return "photo.fill"
        case "mp3", "wav", "m4a": return "music.note"
        case "mp4", "mov", "avi": return "video.fill"
        case "pdf": return "doc.richtext.fill"
        case "zip", "rar", "7z": return "archivebox.fill"
        case "json", "xml": return "doc.badge.gearshape.fill"
        case "js", "ts", "html", "css": return "globe"
        case "py": return "terminal.fill"
        case "java", "kt": return "cup.and.saucer.fill"
        case "cpp", "c", "h": return "hammer.fill"
        default: return "doc.fill"
        }
    }
    
    // MARK: - Utility Methods
    nonisolated public func shouldBeExcluded(configuration: FileSystemHyperScanner.ScanConfiguration) -> Bool {
        // Check hidden files
        if configuration.excludeHiddenFiles && isHidden {
            return true
        }
        
        // Check file size limit
        if !isDirectory && size > configuration.maxFileSize {
            return true
        }
        
        // Check allowed extensions
        if let allowedExtensions = configuration.allowedExtensions,
           !isDirectory && !allowedExtensions.isEmpty {
            return !allowedExtensions.contains(fileExtension)
        }
        
        // Check system directories
        if configuration.excludeSystemDirectories && isDirectory {
            let systemDirs = ["System", "Library", "Applications", "usr", "bin", "sbin", "var", "tmp"]
            if systemDirs.contains(name) {
                return true
            }
        }
        
        return false
    }
    
    nonisolated public var nodeType: FileNode.NodeType {
        if isSymbolicLink {
            return .symbolicLink
        } else if isDirectory {
            return .directory
        } else {
            return .file
        }
    }
}

// MARK: - Hashable Conformance
extension FileSystemItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url.path)
    }
    
    public static func == (lhs: FileSystemItem, rhs: FileSystemItem) -> Bool {
        return lhs.url.path == rhs.url.path
    }
}

// MARK: - Preview Support
extension FileSystemItem {
    public static var previewDirectory: FileSystemItem {
        FileSystemItem(
            url: URL(fileURLWithPath: "/Users/test/Documents"),
            name: "Documents",
            isDirectory: true,
            size: 0,
            createdDate: Date(),
            modifiedDate: Date(),
            isHidden: false,
            isSymbolicLink: false
        )
    }
    
    public static var previewFile: FileSystemItem {
        FileSystemItem(
            url: URL(fileURLWithPath: "/Users/test/Documents/Report.pdf"),
            name: "Report.pdf",
            isDirectory: false,
            size: 1024 * 1024, // 1MB
            createdDate: Date(),
            modifiedDate: Date(),
            isHidden: false,
            isSymbolicLink: false
        )
    }
    
    public static var previewItems: [FileSystemItem] {
        return [
            previewDirectory,
            previewFile,
            FileSystemItem(
                url: URL(fileURLWithPath: "/Users/test/Documents/Presentation.key"),
                name: "Presentation.key",
                isDirectory: false,
                size: 5 * 1024 * 1024, // 5MB
                createdDate: Date(),
                modifiedDate: Date(),
                isHidden: false,
                isSymbolicLink: false
            )
        ]
    }
}