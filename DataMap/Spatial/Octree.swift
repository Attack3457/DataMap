// 📁 File: Spatial/Octree.swift
// 🎯 OCTREE SPATIAL INDEXING FOR GRAPH NODES (SIMPLIFIED FOR GRAPH ARCHITECTURE)

import Foundation
import simd

// MARK: - Octree for Graph-Based File Nodes
@MainActor
public final class Octree {
    
    // MARK: - Node Structure
    private struct Node {
        var bounds: AABB
        var children: [Node?] = Array(repeating: nil, count: 8)
        var nodes: [FileNode] = []
        let maxDepth: Int
        let maxNodesPerLeaf: Int
        
        init(bounds: AABB, maxDepth: Int, maxNodesPerLeaf: Int) {
            self.bounds = bounds
            self.maxDepth = maxDepth
            self.maxNodesPerLeaf = maxNodesPerLeaf
        }
    }
    
    // MARK: - Properties
    private var root: Node
    private let maxDepth: Int
    private let maxNodesPerLeaf: Int
    
    // Statistics
    private var totalNodes: Int = 0
    private var leafNodes: Int = 0
    private var maxDepthReached: Int = 0
    
    // MARK: - Initializer
    public init(bounds: AABB = AABB(min: SIMD3<Float>(0, 0, 0), max: SIMD3<Float>(1, 1, 1)), 
                maxDepth: Int = 8, 
                maxNodesPerLeaf: Int = 10) {
        self.maxDepth = maxDepth
        self.maxNodesPerLeaf = maxNodesPerLeaf
        self.root = Node(bounds: bounds, maxDepth: maxDepth, maxNodesPerLeaf: maxNodesPerLeaf)
    }
    
    // MARK: - Public API
    
    /// Insert multiple nodes
    func insert(nodes: [FileNode]) {
        for node in nodes {
            insert(node: node)
        }
    }
    
    /// Insert a single node
    func insert(node: FileNode) {
        insert(node: node, into: &root, depth: 0)
        updateStatistics()
    }
    
    /// Query nodes within a bounding box
    func query(bounds: AABB) -> [FileNode] {
        var results: [FileNode] = []
        query(node: root, bounds: bounds, results: &results)
        return results
    }
    
    /// Query nodes within a sphere (adapted for 2D graph coordinates)
    func querySphere(center: SIMD2<Float>, radius: Float) -> [FileNode] {
        let center3D = SIMD3<Float>(center.x, center.y, 0)
        let bounds = AABB(
            min: center3D - SIMD3<Float>(radius, radius, radius),
            max: center3D + SIMD3<Float>(radius, radius, radius)
        )
        return query(bounds: bounds)
    }
    
    /// Find nearest neighbors
    func nearestNeighbors(to point: SIMD2<Float>, count: Int) -> [FileNode] {
        var candidates: [(FileNode, Float)] = []
        let point3D = SIMD3<Float>(point.x, point.y, 0)
        
        findNearestNeighbors(node: root, point: point3D, candidates: &candidates)
        
        // Sort by distance and return the closest ones
        candidates.sort { $0.1 < $1.1 }
        return Array(candidates.prefix(count).map { $0.0 })
    }
    
    /// Get all nodes in the octree
    func getAllNodes() -> [FileNode] {
        var results: [FileNode] = []
        collectAllNodes(from: root, results: &results)
        return results
    }
    
    /// Clear all nodes
    func clear() {
        root = Node(bounds: root.bounds, maxDepth: maxDepth, maxNodesPerLeaf: maxNodesPerLeaf)
        totalNodes = 0
        leafNodes = 0
        maxDepthReached = 0
    }
    
    // MARK: - Statistics
    
    public var nodeCount: Int { totalNodes }
    public var leafCount: Int { leafNodes }
    public var depth: Int { maxDepthReached }
    
    // MARK: - Private Methods
    
    private func insert(node: FileNode, into octreeNode: inout Node, depth: Int) {
        maxDepthReached = max(maxDepthReached, depth)
        
        // Convert graph coordinates to 3D position
        let position = SIMD3<Float>(Float(node.graphX), Float(node.graphY), 0)
        
        // Check if position is within bounds
        guard octreeNode.bounds.contains(position) else { return }
        
        // If we haven't reached max depth and have too many nodes, subdivide
        if depth < maxDepth && octreeNode.nodes.count >= maxNodesPerLeaf && octreeNode.children.allSatisfy({ $0 == nil }) {
            subdivide(node: &octreeNode)
        }
        
        // If we have children, try to insert into appropriate child
        if octreeNode.children.contains(where: { $0 != nil }) {
            let childIndex = getChildIndex(for: position, in: octreeNode.bounds)
            if var child = octreeNode.children[childIndex] {
                insert(node: node, into: &child, depth: depth + 1)
                octreeNode.children[childIndex] = child
            }
        } else {
            // Add to this node
            octreeNode.nodes.append(node)
        }
    }
    
    private func subdivide(node: inout Node) {
        let bounds = node.bounds
        let center = bounds.center
        let halfSize = (bounds.max - bounds.min) / 2
        
        // Create 8 child nodes
        for i in 0..<8 {
            let offset = SIMD3<Float>(
                (i & 1) == 0 ? -halfSize.x/2 : halfSize.x/2,
                (i & 2) == 0 ? -halfSize.y/2 : halfSize.y/2,
                (i & 4) == 0 ? -halfSize.z/2 : halfSize.z/2
            )
            
            let childMin = center + offset - halfSize/2
            let childMax = center + offset + halfSize/2
            let childBounds = AABB(min: childMin, max: childMax)
            
            node.children[i] = Node(bounds: childBounds, maxDepth: maxDepth, maxNodesPerLeaf: maxNodesPerLeaf)
        }
        
        // Redistribute existing nodes to children
        let existingNodes = node.nodes
        node.nodes.removeAll()
        
        for existingNode in existingNodes {
            let position = SIMD3<Float>(Float(existingNode.graphX), Float(existingNode.graphY), 0)
            let childIndex = getChildIndex(for: position, in: bounds)
            if var child = node.children[childIndex] {
                child.nodes.append(existingNode)
                node.children[childIndex] = child
            }
        }
    }
    
    private func getChildIndex(for position: SIMD3<Float>, in bounds: AABB) -> Int {
        let center = bounds.center
        var index = 0
        
        if position.x > center.x { index |= 1 }
        if position.y > center.y { index |= 2 }
        if position.z > center.z { index |= 4 }
        
        return index
    }
    
    private func query(node: Node, bounds: AABB, results: inout [FileNode]) {
        // Check if node bounds intersect with query bounds
        if !node.bounds.intersects(bounds) {
            return
        }
        
        // Add nodes that are within the query bounds
        for fileNode in node.nodes {
            let position = SIMD3<Float>(Float(fileNode.graphX), Float(fileNode.graphY), 0)
            if bounds.contains(position) {
                results.append(fileNode)
            }
        }
        
        // Recursively query children
        for child in node.children {
            if let child = child {
                query(node: child, bounds: bounds, results: &results)
            }
        }
    }
    
    private func findNearestNeighbors(node: Node, point: SIMD3<Float>, candidates: inout [(FileNode, Float)]) {
        // Add nodes from this octree node
        for fileNode in node.nodes {
            let nodePos = SIMD3<Float>(Float(fileNode.graphX), Float(fileNode.graphY), 0)
            let distance = length(nodePos - point)
            candidates.append((fileNode, distance))
        }
        
        // Recursively search children
        for child in node.children {
            if let child = child {
                findNearestNeighbors(node: child, point: point, candidates: &candidates)
            }
        }
    }
    
    private func collectAllNodes(from node: Node, results: inout [FileNode]) {
        results.append(contentsOf: node.nodes)
        
        for child in node.children {
            if let child = child {
                collectAllNodes(from: child, results: &results)
            }
        }
    }
    
    private func updateStatistics() {
        totalNodes = getAllNodes().count
        leafNodes = countLeafNodes(node: root)
    }
    
    private func countLeafNodes(node: Node) -> Int {
        if node.children.allSatisfy({ $0 == nil }) {
            return 1
        }
        
        var count = 0
        for child in node.children {
            if let child = child {
                count += countLeafNodes(node: child)
            }
        }
        return count
    }
}

// MARK: - AABB (Axis-Aligned Bounding Box)
public struct AABB: Sendable {
    public let min: SIMD3<Float>
    public let max: SIMD3<Float>
    
    public init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }
    
    public var center: SIMD3<Float> {
        (min + max) / 2
    }
    
    public var size: SIMD3<Float> {
        max - min
    }
    
    public func contains(_ point: SIMD3<Float>) -> Bool {
        return point.x >= min.x && point.x <= max.x &&
               point.y >= min.y && point.y <= max.y &&
               point.z >= min.z && point.z <= max.z
    }
    
    public func intersects(_ other: AABB) -> Bool {
        return min.x <= other.max.x && max.x >= other.min.x &&
               min.y <= other.max.y && max.y >= other.min.y &&
               min.z <= other.max.z && max.z >= other.min.z
    }
}