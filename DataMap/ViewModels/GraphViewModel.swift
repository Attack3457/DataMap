// 📁 File: ViewModels/GraphViewModel.swift
// 🎯 GRAPH-BASED VIEW MODEL

import SwiftUI
import Combine
import SwiftData
import simd

@MainActor
final class GraphViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var nodes: [FileNode] = []
    @Published var edges: [FileEdge] = []
    @Published var layoutPositions: [String: SIMD2<Double>] = [:]
    @Published var selectedNodeId: String?
    @Published var highlightedNodeIds: Set<String> = []
    @Published var isLayoutRunning = false
    @Published var layoutProgress: Double = 0.0
    @Published var highlightRadius: Double = 0.1
    
    // Search and filtering
    @Published var searchText: String = ""
    @Published var filteredNodes: [FileNode] = []
    @Published var showOnlyDirectories = false
    @Published var showOnlyBookmarked = false
    @Published var selectedTags: Set<String> = []
    
    // Loading states
    @Published var isLoading = false
    @Published var scanProgress: Double = 0.0
    @Published var scannedFileCount: Int = 0
    @Published var scanStatus: String = ""
    @Published var error: Error?
    
    // MARK: - Private Properties
    private let layoutEngine: ForceDirectedLayoutEngine
    private var cancellables = Set<AnyCancellable>()
    private var layoutTask: Task<Void, Never>?
    private let fileSystemScanner: FileSystemHyperScanner
    
    // MARK: - Configuration
    struct Configuration {
        var layoutQuality: LayoutQuality = .high
        var showLabels: Bool = true
        var showEdges: Bool = true
        var animateLayout: Bool = true
        var nodeScaling: NodeScaling = .sizeBased
        var edgeStrength: Double = 1.0
        var repulsionStrength: Double = 100.0
        
        enum LayoutQuality {
            case low      // 100 iterations
            case medium   // 300 iterations
            case high     // 500 iterations
            case ultra    // 1000 iterations
            
            var iterations: Int {
                switch self {
                case .low: return 100
                case .medium: return 300
                case .high: return 500
                case .ultra: return 1000
                }
            }
        }
        
        enum NodeScaling {
            case uniform
            case sizeBased
            case depthBased
        }
    }
    
    @Published var configuration = Configuration()
    
    // MARK: - Computed Properties
    var visibleNodes: [FileNode] {
        let filtered = applyFilters(to: nodes)
        
        // Apply highlight radius filtering if a node is selected
        if let selectedId = selectedNodeId,
           let selectedPos = layoutPositions[selectedId] {
            return filtered.filter { node in
                guard let position = layoutPositions[node.id.uuidString] else { return false }
                let distance = length(position - selectedPos)
                return distance <= highlightRadius
            }
        }
        
        return filtered
    }
    
    var visibleEdges: [FileEdge] {
        guard configuration.showEdges else { return [] }
        
        let visibleNodeIds = Set(visibleNodes.map { $0.id.uuidString })
        return edges.filter { edge in
            visibleNodeIds.contains(edge.sourceId) && visibleNodeIds.contains(edge.targetId)
        }
    }
    
    var allTags: [String] {
        Array(Set(nodes.flatMap { $0.tags })).sorted()
    }
    
    // MARK: - Initializer
    init() {
        self.layoutEngine = ForceDirectedLayoutEngine()
        self.fileSystemScanner = FileSystemHyperScanner(
            coordinateEngine: CoordinateEngine()
        )
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Load nodes from a directory path
    func loadDirectory(_ path: String) async {
        isLoading = true
        error = nil
        
        do {
            // Scan file system using the correct method
            let rootNode = try await fileSystemScanner.scanDirectory(at: path)
            
            // Convert hierarchy to flat array
            let fileNodes = flattenHierarchy(rootNode)
            
            // Update UI
            self.nodes = fileNodes
            self.edges = createEdges(from: fileNodes)
            self.filteredNodes = fileNodes
            
            // Start layout calculation
            await calculateLayout()
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Load nodes from existing hierarchy
    func loadHierarchy(_ nodes: [FileNode]) {
        self.nodes = nodes
        self.edges = createEdges(from: nodes)
        self.filteredNodes = nodes
        
        // Start layout calculation
        Task {
            await calculateLayout()
        }
    }
    
    /// Select a node (centers view on it)
    func selectNode(_ nodeId: String?) {
        selectedNodeId = nodeId
        
        if let nodeId = nodeId {
            // Highlight connected nodes
            highlightConnectedNodes(nodeId)
        } else {
            highlightedNodeIds.removeAll()
        }
    }
    
    /// Zoom in/out (affects highlight radius)
    func zoom(_ scale: Double) {
        highlightRadius *= scale
        highlightRadius = max(0.01, min(highlightRadius, 1.0))
    }
    
    /// Start/stop layout animation
    func toggleLayoutAnimation() {
        if isLayoutRunning {
            stopLayout()
        } else {
            startLayoutAnimation()
        }
    }
    
    /// Reset layout positions
    func resetLayout() {
        Task {
            await layoutEngine.reset()
            await calculateLayout()
        }
    }
    
    /// Export graph data
    func exportGraph() async -> Data? {
        let exportData = GraphExportData(
            nodes: nodes.map { GraphNodeData(from: $0) },
            edges: edges,
            positions: layoutPositions,
            configuration: configuration
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    /// Search nodes
    func search(_ query: String) {
        searchText = query
        updateFilteredNodes()
    }
    
    /// Toggle directory filter
    func toggleDirectoryFilter() {
        showOnlyDirectories.toggle()
        updateFilteredNodes()
    }
    
    /// Toggle bookmark filter
    func toggleBookmarkFilter() {
        showOnlyBookmarked.toggle()
        updateFilteredNodes()
    }
    
    /// Add/remove tag filter
    func toggleTagFilter(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        updateFilteredNodes()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // React to search text changes
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFilteredNodes()
            }
            .store(in: &cancellables)
        
        // React to configuration changes
        $configuration
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    await self?.recalculateLayout()
                }
            }
            .store(in: &cancellables)
        
        // React to filter changes
        Publishers.CombineLatest4($showOnlyDirectories, $showOnlyBookmarked, $selectedTags, $nodes)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                self?.updateFilteredNodes()
            }
            .store(in: &cancellables)
    }
    
    private func convertToFileNodes(_ items: [FileSystemItem]) async -> [FileNode] {
        var nodeMap: [String: FileNode] = [:]
        var rootNodes: [FileNode] = []
        
        // First pass: create all nodes
        for item in items {
            let node = FileNode.createFromFileItem(item)
            nodeMap[item.url.path] = node
        }
        
        // Second pass: establish parent-child relationships
        for item in items {
            guard let node = nodeMap[item.url.path] else { continue }
            
            let parentPath = item.url.deletingLastPathComponent().path
            if let parent = nodeMap[parentPath] {
                parent.addChild(node)
            } else {
                rootNodes.append(node)
            }
        }
        
        return Array(nodeMap.values)
    }
    
    private func createEdges(from nodes: [FileNode]) -> [FileEdge] {
        var edges: [FileEdge] = []
        
        for node in nodes {
            // Parent-child edges
            if let parent = node.parent {
                let edge = FileEdge(
                    sourceId: parent.id.uuidString,
                    targetId: node.id.uuidString,
                    strength: calculateEdgeStrength(parent: parent, child: node)
                )
                edges.append(edge)
            }
            
            // Sibling edges (optional, for clustering)
            if configuration.layoutQuality == .ultra {
                for sibling in node.children {
                    if sibling.id != node.id {
                        let edge = FileEdge(
                            sourceId: node.id.uuidString,
                            targetId: sibling.id.uuidString,
                            strength: 0.1 // Weak sibling connection
                        )
                        edges.append(edge)
                    }
                }
            }
        }
        
        return edges
    }
    
    private func calculateEdgeStrength(parent: FileNode, child: FileNode) -> Double {
        var strength = configuration.edgeStrength
        
        // Stronger connections for:
        // - Small directories
        // - Recently accessed files
        // - Bookmarked items
        if child.isDirectory && child.children.count < 10 {
            strength *= 2.0
        }
        
        if child.isBookmarked {
            strength *= 1.5
        }
        
        // Weaker for symbolic links
        if child.nodeType == .symbolicLink {
            strength *= 0.5
        }
        
        return strength
    }
    
    private func calculateLayout() async {
        layoutTask?.cancel()
        
        layoutTask = Task {
            isLayoutRunning = true
            layoutProgress = 0.0
            
        do {
            // Configure layout engine based on quality setting
            var config = ForceDirectedLayoutEngine.Configuration.default
            config.maxIterations = configuration.layoutQuality.iterations
            config.repulsionStrength = configuration.repulsionStrength
            
            let engine = ForceDirectedLayoutEngine(configuration: config)
            let positions = await engine.layout(for: nodes, edges: edges)
            
            // Convert to dictionary
            var positionsDict: [String: SIMD2<Double>] = [:]
            for position in positions {
                positionsDict[position.id] = position.position
            }
            
            await MainActor.run {
                self.layoutPositions = positionsDict
                self.isLayoutRunning = false
                self.layoutProgress = 1.0
            }
        }
        }
    }
    
    private func recalculateLayout() async {
        await calculateLayout()
    }
    
    private func startLayoutAnimation() {
        isLayoutRunning = true
        
        Task {
            for iteration in 0..<100 {
                guard isLayoutRunning else { break }
                
                await layoutEngine.updateLayout()
                
                await MainActor.run {
                    self.layoutProgress = Double(iteration) / 100.0
                }
                
                await Task.yield()
            }
            
            await MainActor.run {
                self.isLayoutRunning = false
                self.layoutProgress = 1.0
            }
        }
    }
    
    private func stopLayout() {
        isLayoutRunning = false
        layoutTask?.cancel()
    }
    
    private func highlightConnectedNodes(_ nodeId: String) {
        // Find all nodes connected to this node
        var connectedIds: Set<String> = [nodeId]
        
        // Breadth-first search through edges
        var queue: [String] = [nodeId]
        while !queue.isEmpty {
            let currentId = queue.removeFirst()
            
            for edge in edges where edge.sourceId == currentId || edge.targetId == currentId {
                let otherId = edge.sourceId == currentId ? edge.targetId : edge.sourceId
                if !connectedIds.contains(otherId) {
                    connectedIds.insert(otherId)
                    queue.append(otherId)
                }
            }
        }
        
        highlightedNodeIds = connectedIds
    }
    
    private func applyFilters(to nodes: [FileNode]) -> [FileNode] {
        var filtered = nodes
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { node in
                node.name.localizedCaseInsensitiveContains(searchText) ||
                node.path.localizedCaseInsensitiveContains(searchText) ||
                node.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Directory filter
        if showOnlyDirectories {
            filtered = filtered.filter { $0.isDirectory }
        }
        
        // Bookmark filter
        if showOnlyBookmarked {
            filtered = filtered.filter { $0.isBookmarked }
        }
        
        // Tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { node in
                !Set(node.tags).isDisjoint(with: selectedTags)
            }
        }
        
        return filtered
    }
    
    private func updateFilteredNodes() {
        filteredNodes = applyFilters(to: nodes)
    }
    
    /// Load existing data (for compatibility)
    func loadExistingData() async {
        // This method exists for compatibility with SidebarView
        // In the graph-based architecture, data is loaded via loadDirectory or loadHierarchy
    }
    
    /// Scan directory (compatibility method)
    func scanDirectory(_ url: URL) async {
        await loadDirectory(url.path)
    }
    
    /// Calculate file system statistics
    func calculateStatistics() -> FileSystemStatistics {
        let totalFiles = nodes.filter { !$0.isDirectory }.count
        let totalFolders = nodes.filter { $0.isDirectory }.count
        let totalSize = nodes.reduce(0) { $0 + $1.size }
        
        return FileSystemStatistics(
            totalFiles: totalFiles,
            totalFolders: totalFolders,
            totalSize: totalSize
        )
    }
    
    /// Flatten hierarchical FileNode structure into array
    private func flattenHierarchy(_ rootNode: FileNode) -> [FileNode] {
        var result: [FileNode] = []
        var queue: [FileNode] = [rootNode]
        
        while !queue.isEmpty {
            let node = queue.removeFirst()
            result.append(node)
            queue.append(contentsOf: node.children)
        }
        
        return result
    }
}

// MARK: - Supporting Types

struct FileSystemStatistics {
    let totalFiles: Int
    let totalFolders: Int
    let totalSize: Int64
}

// MARK: - Supporting Types

struct GraphExportData: Codable {
    let nodes: [GraphNodeData]
    let edges: [FileEdge]
    let positions: [String: SIMD2<Double>]
    let configuration: GraphViewModel.Configuration
}

struct GraphNodeData: Codable {
    let id: String
    let name: String
    let path: String
    let nodeType: FileNode.NodeType
    let size: Int64
    let isBookmarked: Bool
    let tags: [String]
    
    init(from node: FileNode) {
        self.id = node.id.uuidString
        self.name = node.name
        self.path = node.path
        self.nodeType = node.nodeType
        self.size = node.size
        self.isBookmarked = node.isBookmarked
        self.tags = node.tags
    }
}

// MARK: - Configuration Codable Conformance
extension GraphViewModel.Configuration: Codable {
    enum CodingKeys: String, CodingKey {
        case layoutQuality, showLabels, showEdges, animateLayout
        case nodeScaling, edgeStrength, repulsionStrength
    }
}

extension GraphViewModel.Configuration.LayoutQuality: Codable {}
extension GraphViewModel.Configuration.NodeScaling: Codable {}

// MARK: - SIMD2 Codable Conformance (Remove duplicate)
// Note: SIMD2 already conforms to Codable in Swift, so we don't need this extension