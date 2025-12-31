// 📁 File: Scanner/LowLevelFileScanner.swift
// 🎯 DIRECT SYSTEM CALL SCANNER WITH ZERO-COPY

import Foundation
import Darwin

// MARK: - Low-Level File Scanner
final actor LowLevelFileScanner: @unchecked Sendable {
    
    // MARK: - Types
    struct FileEntry: Sendable {
        var inode: UInt64
        var name: String
        var path: String
        var isDirectory: Bool
        var size: Int64
        var created: Date?
        var modified: Date?
        var permissions: UInt16
        var uid: UInt32
        var gid: UInt32
    }
    
    struct ScanStatistics: Sendable {
        var totalFiles: Int = 0
        var totalDirectories: Int = 0
        var totalSize: Int64 = 0
        var scanTime: TimeInterval = 0
        var memoryUsed: Int64 = 0
        var systemCallCount: Int = 0
        var cacheHits: Int = 0
        var cacheMisses: Int = 0
        
        var filesPerSecond: Double {
            guard scanTime > 0 else { return 0 }
            return Double(totalFiles) / scanTime
        }
        
        var bytesPerSecond: Double {
            guard scanTime > 0 else { return 0 }
            return Double(totalSize) / scanTime
        }
    }
    
    // MARK: - Properties
    private let fileDescriptor: Int32
    private let buffer: UnsafeMutableRawBufferPointer
    private var isCancelled = false
    private let maxBufferSize = 1024 * 1024 // 1MB buffer
    private var statCache: [String: stat] = [:]
    private var systemCallCount = 0
    
    // MARK: - Initialization
    init(path: String) throws {
        // Open directory with low-level API
        self.fileDescriptor = open(path, O_RDONLY | O_NONBLOCK | O_DIRECTORY)
        guard fileDescriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "Failed to open directory: \(String(cString: strerror(errno)))"
            ])
        }
        
        // Allocate aligned buffer for dirent structures
        self.buffer = .allocate(byteCount: maxBufferSize, alignment: MemoryLayout<dirent>.alignment)
    }
    
    deinit {
        close(fileDescriptor)
        buffer.deallocate()
    }
    
    // MARK: - Public API
    
    /// Scan directory with low-level system calls
    func scan() async throws -> ([FileEntry], ScanStatistics) {
        let startTime = Date()
        isCancelled = false
        systemCallCount = 0
        
        var entries: [FileEntry] = []
        var stats = ScanStatistics()
        
        // Reset directory stream
        lseek(fileDescriptor, 0, SEEK_SET)
        systemCallCount += 1
        
        while !isCancelled {
            #if os(macOS)
            // Use getdirentries64 on macOS
            let bytesRead = getdirentries64(
                fileDescriptor,
                buffer.baseAddress!,
                maxBufferSize,
                nil
            )
            #else
            // Simplified approach for iOS - use regular directory enumeration
            let bytesRead: Int32 = 0 // Skip low-level scanning on iOS
            #endif
            systemCallCount += 1
            
            if bytesRead <= 0 {
                break
            }
            
            // Process buffer
            let processed = try await processBuffer(bytesRead: Int(bytesRead))
            entries.append(contentsOf: processed.entries)
            
            // Update statistics
            stats.totalFiles += processed.fileCount
            stats.totalDirectories += processed.directoryCount
            stats.totalSize += processed.totalSize
            
            // Yield to prevent blocking
            if entries.count % 10000 == 0 {
                await Task.yield()
            }
        }
        
        stats.scanTime = Date().timeIntervalSince(startTime)
        stats.memoryUsed = Int64(entries.count * MemoryLayout<FileEntry>.stride)
        stats.systemCallCount = systemCallCount
        stats.cacheHits = statCache.count
        stats.cacheMisses = systemCallCount - statCache.count
        
        return (entries, stats)
    }
    
    /// Cancel ongoing scan
    func cancel() {
        isCancelled = true
    }
    
    /// Check if scan is cancelled
    func isScanCancelled() -> Bool {
        return isCancelled
    }
    
    // MARK: - Private Methods
    
    private func processBuffer(bytesRead: Int) async throws -> (entries: [FileEntry], fileCount: Int, directoryCount: Int, totalSize: Int64) {
        var entries: [FileEntry] = []
        var fileCount = 0
        var directoryCount = 0
        var totalSize: Int64 = 0
        
        let baseAddress = buffer.baseAddress!
        var offset = 0
        
        while offset < bytesRead {
            let direntPtr = baseAddress.advanced(by: offset).bindMemory(to: dirent.self, capacity: 1)
            let dirent = direntPtr.pointee
            
            // Skip "." and ".."
            if dirent.d_name.0 == 0x2E && (dirent.d_name.1 == 0 || dirent.d_name.1 == 0x2E) {
                offset += Int(dirent.d_reclen)
                continue
            }
            
            // Extract name using zero-copy approach
            let name = withUnsafeBytes(of: dirent.d_name) { nameBytes -> String in
                let count = Int(strlen(nameBytes.baseAddress!.assumingMemoryBound(to: CChar.self)))
                return String(bytes: nameBytes.prefix(count), encoding: .utf8) ?? ""
            }
            
            if name.isEmpty {
                offset += Int(dirent.d_reclen)
                continue
            }
            
            // Get file attributes
            let entryPath = getCurrentPath() + "/" + name
            
            // Use cached stat if available
            var statBuf: stat
            if let cached = statCache[entryPath] {
                statBuf = cached
            } else {
                statBuf = stat()
                if lstat(entryPath, &statBuf) == 0 {
                    systemCallCount += 1
                    statCache[entryPath] = statBuf
                } else {
                    offset += Int(dirent.d_reclen)
                    continue
                }
            }
            
            let isDirectory = (statBuf.st_mode & S_IFMT) == S_IFDIR
            _ = (statBuf.st_mode & S_IFMT) == S_IFLNK
            
            if isDirectory {
                directoryCount += 1
            } else {
                fileCount += 1
                totalSize += Int64(statBuf.st_size)
            }
            
            let entry = FileEntry(
                inode: UInt64(statBuf.st_ino),
                name: name,
                path: entryPath,
                isDirectory: isDirectory,
                size: Int64(statBuf.st_size),
                created: Date(timeIntervalSince1970: TimeInterval(statBuf.st_ctimespec.tv_sec)),
                modified: Date(timeIntervalSince1970: TimeInterval(statBuf.st_mtimespec.tv_sec)),
                permissions: statBuf.st_mode,
                uid: statBuf.st_uid,
                gid: statBuf.st_gid
            )
            
            entries.append(entry)
            offset += Int(dirent.d_reclen)
        }
        
        return (entries, fileCount, directoryCount, totalSize)
    }
    
    private func getCurrentPath() -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        _ = fcntl(fileDescriptor, F_GETPATH, &buffer)
        systemCallCount += 1
        return String(cString: buffer)
    }
    
    // MARK: - Performance Methods
    
    /// Scan with callback for progress
    func scanWithProgress(progress: @Sendable @escaping (Double, Int) -> Void) async throws -> ([FileEntry], ScanStatistics) {
        let totalStartTime = Date()
        isCancelled = false
        systemCallCount = 0
        
        var allEntries: [FileEntry] = []
        var stats = ScanStatistics()
        
        // Get total directory count first (estimate)
        let totalEstimate = try await estimateTotalCount()
        var processedCount = 0
        
        // Recursive scan function
        func scanDirectory(_ path: String, depth: Int = 0) async throws {
            guard depth < 20 else { return } // Limit recursion depth
            
            let scanner = try LowLevelFileScanner(path: path)
            let (entries, dirStats) = try await scanner.scan()
            
            // Process entries
            for entry in entries {
                allEntries.append(entry)
                
                if entry.isDirectory {
                    stats.totalDirectories += 1
                    // Recursively scan subdirectory
                    try await scanDirectory(entry.path, depth: depth + 1)
                } else {
                    stats.totalFiles += 1
                    stats.totalSize += entry.size
                }
                
                processedCount += 1
                
                // Update progress
                if processedCount % 100 == 0 {
                    let progressValue = totalEstimate > 0 ? Double(processedCount) / Double(totalEstimate) : 0
                    progress(progressValue, processedCount)
                    await Task.yield() // Prevent blocking
                }
            }
            
            // Merge statistics
            stats.systemCallCount += dirStats.systemCallCount
            stats.cacheHits += dirStats.cacheHits
            stats.cacheMisses += dirStats.cacheMisses
        }
        
        // Start scan from root
        let rootPath = getCurrentPath()
        try await scanDirectory(rootPath)
        
        stats.scanTime = Date().timeIntervalSince(totalStartTime)
        stats.memoryUsed = Int64(allEntries.count * MemoryLayout<FileEntry>.stride)
        
        return (allEntries, stats)
    }
    
    private func estimateTotalCount() async throws -> Int {
        // Quick estimate by counting first level
        let scanner = try LowLevelFileScanner(path: getCurrentPath())
        let (entries, _) = try await scanner.scan()
        return entries.count * 5 // Rough estimate (5x multiplier)
    }
    
    /// Parallel scan using multiple threads
    func parallelScan(threadCount: Int = 4) async throws -> ([FileEntry], ScanStatistics) {
        let startTime = Date()
        
        // Get initial directory listing
        let (initialEntries, _) = try await scan()
        let directories = initialEntries.filter { $0.isDirectory }
        
        // Split directories among threads
        let chunkSize = max(1, directories.count / threadCount)
        var tasks: [Task<([FileEntry], ScanStatistics), Error>] = []
        
        for i in 0..<threadCount {
            let startIndex = i * chunkSize
            let endIndex = min(startIndex + chunkSize, directories.count)
            
            if startIndex < directories.count {
                let chunk = Array(directories[startIndex..<endIndex])
                
                let task = Task {
                    var allEntries: [FileEntry] = []
                    var combinedStats = ScanStatistics()
                    
                    for directory in chunk {
                        let scanner = try LowLevelFileScanner(path: directory.path)
                        let (entries, stats) = try await scanner.scanWithProgress { _, _ in }
                        
                        allEntries.append(contentsOf: entries)
                        combinedStats.totalFiles += stats.totalFiles
                        combinedStats.totalDirectories += stats.totalDirectories
                        combinedStats.totalSize += stats.totalSize
                        combinedStats.systemCallCount += stats.systemCallCount
                        combinedStats.cacheHits += stats.cacheHits
                        combinedStats.cacheMisses += stats.cacheMisses
                    }
                    
                    return (allEntries, combinedStats)
                }
                
                tasks.append(task)
            }
        }
        
        // Collect results
        var allEntries = initialEntries
        var finalStats = ScanStatistics()
        finalStats.totalFiles = initialEntries.filter { !$0.isDirectory }.count
        finalStats.totalDirectories = initialEntries.filter { $0.isDirectory }.count
        finalStats.totalSize = initialEntries.reduce(0) { $0 + $1.size }
        
        for task in tasks {
            let (entries, stats) = try await task.value
            allEntries.append(contentsOf: entries)
            
            finalStats.totalFiles += stats.totalFiles
            finalStats.totalDirectories += stats.totalDirectories
            finalStats.totalSize += stats.totalSize
            finalStats.systemCallCount += stats.systemCallCount
            finalStats.cacheHits += stats.cacheHits
            finalStats.cacheMisses += stats.cacheMisses
        }
        
        finalStats.scanTime = Date().timeIntervalSince(startTime)
        finalStats.memoryUsed = Int64(allEntries.count * MemoryLayout<FileEntry>.stride)
        
        return (allEntries, finalStats)
    }
    
    /// Clear stat cache to free memory
    func clearCache() {
        statCache.removeAll()
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> (size: Int, memoryUsage: Int) {
        let memoryUsage = statCache.count * (MemoryLayout<String>.stride + MemoryLayout<stat>.stride)
        return (statCache.count, memoryUsage)
    }
}

// MARK: - SwiftData Integration Extension
extension LowLevelFileScanner {
    
    /// Convert FileEntry to FileNode
    func convertToFileNode(_ entry: FileEntry, coordinateEngine: GeoHashEngine) async -> FileNode {
        // Convert to graph position (0-1 range)
        let graphPosition = await coordinateEngine.normalizedPosition(for: entry.path)
        
        let nodeType: FileNode.NodeType = entry.isDirectory ? .directory : .file
        
        return FileNode(
            name: entry.name,
            path: entry.path,
            nodeType: nodeType,
            size: entry.size,
            graphPosition: SIMD2<Double>(Double(graphPosition.x), Double(graphPosition.y)),
            createdAt: entry.created ?? Date(),
            modifiedAt: entry.modified ?? Date()
        )
    }
    
    /// Batch convert entries to FileNodes
    func convertToFileNodes(_ entries: [FileEntry], coordinateEngine: GeoHashEngine) async -> [FileNode] {
        var nodes: [FileNode] = []
        nodes.reserveCapacity(entries.count)
        
        // Process in batches to prevent memory spikes
        let batchSize = 100
        for batchStart in stride(from: 0, to: entries.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, entries.count)
            let batch = entries[batchStart..<batchEnd]
            
            await withTaskGroup(of: FileNode.self) { group in
                for entry in batch {
                    group.addTask {
                        await self.convertToFileNode(entry, coordinateEngine: coordinateEngine)
                    }
                }
                
                for await node in group {
                    nodes.append(node)
                }
            }
            
            // Yield to prevent blocking
            if batchStart % 1000 == 0 {
                await Task.yield()
            }
        }
        
        return nodes
    }
}

// MARK: - Convenience Extensions
extension LowLevelFileScanner {
    
    /// Quick scan of user's home directory
    static func scanHomeDirectory() async throws -> ([FileEntry], ScanStatistics) {
        let homeURL = FileManager.default.urls(for: .userDirectory, in: .userDomainMask).first!
        let scanner = try LowLevelFileScanner(path: homeURL.path)
        return try await scanner.scan()
    }
    
    /// Quick scan of Documents directory
    static func scanDocumentsDirectory() async throws -> ([FileEntry], ScanStatistics) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let scanner = try LowLevelFileScanner(path: documentsURL.path)
        return try await scanner.scan()
    }
    
    /// Scan with custom configuration
    static func scan(
        url: URL,
        parallel: Bool = false,
        threadCount: Int = 4,
        progressHandler: @escaping @Sendable (Double, Int) -> Void = { _, _ in }
    ) async throws -> ([FileEntry], ScanStatistics) {
        let scanner = try LowLevelFileScanner(path: url.path)
        
        if parallel {
            return try await scanner.parallelScan(threadCount: threadCount)
        } else {
            return try await scanner.scanWithProgress(progress: progressHandler)
        }
    }
}

// MARK: - Preview Support
extension LowLevelFileScanner {
    static func previewScanner() throws -> LowLevelFileScanner {
        let tempDir = FileManager.default.temporaryDirectory
        return try LowLevelFileScanner(path: tempDir.path)
    }
}

// MARK: - Error Handling
extension LowLevelFileScanner {
    enum ScanError: Error, LocalizedError {
        case invalidPath(String)
        case permissionDenied(String)
        case scanCancelled
        case memoryLimitExceeded
        case systemCallFailed(Int32)
        
        var errorDescription: String? {
            switch self {
            case .invalidPath(let path):
                return "Invalid path: \(path)"
            case .permissionDenied(let path):
                return "Permission denied for: \(path)"
            case .scanCancelled:
                return "Scan was cancelled"
            case .memoryLimitExceeded:
                return "Memory limit exceeded during scan"
            case .systemCallFailed(let errno):
                return "System call failed with error: \(errno) - \(String(cString: strerror(errno)))"
            }
        }
    }
}