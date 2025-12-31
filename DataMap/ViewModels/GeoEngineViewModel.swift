// 📁 File: ViewModels/GeoEngineViewModel.swift
// 🎯 LEGACY VIEW MODEL - REPLACED BY GRAPHVIEWMODEL
// This file is kept for compatibility but is no longer used in the graph-based architecture

import SwiftUI
import Combine
import MapKit
import SwiftData

/*
 * LEGACY CODE - NO LONGER USED
 * This GeoEngineViewModel has been replaced by GraphViewModel
 * for the new graph-based file system visualization.
 * 
 * The graph-based approach provides:
 * - Force-directed layout algorithms
 * - Interactive node manipulation
 * - Better performance with large datasets
 * - More intuitive spatial relationships
 */

@MainActor
final class GeoEngineViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var nodes: [FileNode] = []
    @Published var filteredNodes: [FileNode] = []
    @Published var isLoading = false
    @Published var error: GeoMapperError?
    @Published var scanProgress: Double = 0
    @Published var scannedFileCount: Int = 0
    @Published var scanStatus: String = ""
    
    // MARK: - Private Properties
    private let coordinateEngine: CoordinateEngine
    private var cancellables = Set<AnyCancellable>()
    private var allNodes: [FileNode] = []
    private var nodeIndex: [String: FileNode] = [:]
    
    // MARK: - Filter State
    @Published var filterState = FilterState()
    
    struct FilterState {
        var searchText: String = ""
        var showOnlyDirectories: Bool = false
        var showOnlyBookmarked: Bool = false
        var selectedTags: Set<String> = []
        var sizeRange: ClosedRange<Double> = 0...Double.greatestFiniteMagnitude
        var dateRange: ClosedRange<Date>?
        var selectedFileTypes: Set<String> = []
    }
    
    // MARK: - Computed Properties
    var hasData: Bool {
        !allNodes.isEmpty
    }
    
    var visibleNodes: [FileNode] {
        return filteredNodes
    }
    
    // MARK: - Initializer
    init() {
        self.coordinateEngine = CoordinateEngine()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Load directory and convert to nodes
    func loadDirectory(_ url: URL) async {
        // This method is deprecated - use GraphViewModel.loadDirectory instead
        print("⚠️ GeoEngineViewModel.loadDirectory is deprecated. Use GraphViewModel instead.")
    }
    
    /// Search for a node by name or path
    func searchNode(named query: String) async -> FileNode? {
        // This method is deprecated - use GraphViewModel.search instead
        print("⚠️ GeoEngineViewModel.searchNode is deprecated. Use GraphViewModel instead.")
        return nil
    }
    
    /// Get nodes within a region (deprecated)
    func nodesInRegion(_ region: MKCoordinateRegion) -> [FileNode] {
        // This method is deprecated - geographic regions not applicable to graph layout
        print("⚠️ GeoEngineViewModel.nodesInRegion is deprecated. Use GraphViewModel filtering instead.")
        return []
    }
    
    /// Get parent-child hierarchy for a node
    func getHierarchy(for node: FileNode) -> (ancestors: [FileNode], descendants: [FileNode]) {
        // This method is deprecated - use FileNode.ancestors and FileNode.allDescendants instead
        print("⚠️ GeoEngineViewModel.getHierarchy is deprecated. Use FileNode properties instead.")
        return ([], [])
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Legacy binding setup - no longer used
    }
    
    private func applyFilters() {
        // Legacy filtering - replaced by GraphViewModel
    }
    
    private func updateNodeIndex() {
        // Legacy indexing - replaced by GraphViewModel
    }
}

// MARK: - Preview Support (Deprecated)
extension GeoEngineViewModel {
    static var previewViewModel: GeoEngineViewModel {
        print("⚠️ GeoEngineViewModel preview is deprecated. Use GraphViewModel instead.")
        return GeoEngineViewModel()
    }
}