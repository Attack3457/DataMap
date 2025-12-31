// 📁 File: Spatial/BVHTree.swift
// 🎯 BOUNDING VOLUME HIERARCHY FOR O(LOG N) SPATIAL QUERIES

import Foundation
import CoreLocation
import simd

// MARK: - BVH Tree Implementation
@MainActor
final class BVHTree: @unchecked Sendable {
    
    // MARK: - Node Structure
    struct Node: Sendable {
        var bounds: SIMD4<Float> // minX, minY, maxX, maxY
        var children: (Int32, Int32, Int32, Int32) // Up to 4 children for quad-tree like structure
        var leafCount: Int32
        var leafOffset: Int32
        
        init() {
            bounds = SIMD4<Float>(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, 
                                 -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
            children = (-1, -1, -1, -1)
            leafCount = 0
            leafOffset = -1
        }
        
        var isLeaf: Bool {
            return leafCount > 0
        }
    }
    
    // MARK: - Properties
    private var nodes: [Node] = []
    private var leaves: [FileNode] = []
    private let maxDepth: Int
    private let maxLeafSize: Int
    
    // MARK: - Statistics
    private(set) var totalNodes: Int = 0
    private(set) var leafNodes: Int = 0
    private(set) var maxDepthReached: Int = 0
    
    // MARK: - Initialization
    init(maxDepth: Int = 20, maxLeafSize: Int = 8) {
        self.maxDepth = maxDepth
        self.maxLeafSize = maxLeafSize
    }
    
    // MARK: - Public API
    
    /// Build BVH from array of FileNodes
    func build(from fileNodes: [FileNode]) async {
        self.leaves = fileNodes
        self.nodes.removeAll()
        self.nodes.reserveCapacity(fileNodes.count * 2) // Estimate
        
        if !fileNodes.isEmpty {
            let indices = Array(0..<fileNodes.count)
            _ = self.buildRecursive(nodeIndices: indices, depth: 0)
        }
        
        self.totalNodes = self.nodes.count
        self.leafNodes = self.nodes.filter { $0.isLeaf }.count
        
        print("BVH built: \(self.totalNodes) nodes, \(self.leafNodes) leaves, max depth: \(self.maxDepthReached)")
    }
    
    /// Query nodes within a bounding box
    func query(bounds: SIMD4<Float>) -> [FileNode] {
        guard !nodes.isEmpty else { return [] }
        
        var results: [FileNode] = []
        var stack: [Int] = [0] // Start with root
        
        while let nodeIndex = stack.popLast() {
            let node = nodes[nodeIndex]
            
            // Check if node bounds intersect with query bounds
            if !intersects(node.bounds, bounds) {
                continue
            }
            
            if node.isLeaf {
                // Leaf node - add all contained nodes
                let start = Int(node.leafOffset)
                let end = start + Int(node.leafCount)
                for i in start..<end {
                    if i < leaves.count {
                        let leaf = leaves[i]
                        if pointInBounds(leaf.graphPosition, bounds) {
                            results.append(leaf)
                        }
                    }
                }
            } else {
                // Internal node - add children to stack
                if node.children.0 >= 0 { stack.append(Int(node.children.0)) }
                if node.children.1 >= 0 { stack.append(Int(node.children.1)) }
                if node.children.2 >= 0 { stack.append(Int(node.children.2)) }
                if node.children.3 >= 0 { stack.append(Int(node.children.3)) }
            }
        }
        
        return results
    }
    
    /// Query nodes within a radius of a point
    func queryRadius(center: SIMD2<Float>, radius: Float) -> [FileNode] {
        let bounds = SIMD4<Float>(
            center.x - radius,
            center.y - radius,
            center.x + radius,
            center.y + radius
        )
        
        let candidates = query(bounds: bounds)
        
        // Filter by actual distance
        return candidates.filter { node in
            let nodePos = SIMD2<Float>(Float(node.graphX), Float(node.graphY))
            let distance = length(nodePos - center)
            return distance <= radius
        }
    }
    
    /// Get nearest neighbors
    func nearestNeighbors(to point: SIMD2<Float>, count: Int) -> [FileNode] {
        guard !leaves.isEmpty else { return [] }
        
        // Start with a small radius and expand if needed
        var radius: Float = 1.0
        var results: [FileNode] = []
        
        while results.count < count && radius < 180.0 {
            results = queryRadius(center: point, radius: radius)
            radius *= 2.0
        }
        
        // Sort by distance and take the closest ones
        let sortedResults = results.sorted { node1, node2 in
            let pos1 = SIMD2<Float>(Float(node1.graphX), Float(node1.graphY))
            let pos2 = SIMD2<Float>(Float(node2.graphX), Float(node2.graphY))
            let dist1 = length(pos1 - point)
            let dist2 = length(pos2 - point)
            return dist1 < dist2
        }
        
        return Array(sortedResults.prefix(count))
    }
    
    /// Clear the tree
    func clear() {
        nodes.removeAll()
        leaves.removeAll()
        totalNodes = 0
        leafNodes = 0
        maxDepthReached = 0
    }
    
    // MARK: - Private Methods
    
    private func buildRecursive(nodeIndices: [Int], depth: Int) -> Int {
        maxDepthReached = max(maxDepthReached, depth)
        
        guard !nodeIndices.isEmpty else { return -1 }
        
        let nodeIndex = nodes.count
        var node = Node()
        
        // Calculate bounds for this node
        node.bounds = calculateBounds(for: nodeIndices)
        
        // Check if we should create a leaf
        if depth >= maxDepth || nodeIndices.count <= maxLeafSize {
            // Create leaf node
            node.leafCount = Int32(nodeIndices.count)
            node.leafOffset = Int32(leaves.count)
            
            // Add nodes to leaves array (they're already there, just record the range)
            // The indices refer to positions in the original leaves array
            
            nodes.append(node)
            return nodeIndex
        }
        
        // Split the node indices into quadrants
        let quadrants = splitIntoQuadrants(nodeIndices: nodeIndices, bounds: node.bounds)
        
        // Recursively build children
        var childIndices: [Int32] = [-1, -1, -1, -1]
        for (i, quadrant) in quadrants.enumerated() {
            if !quadrant.isEmpty {
                let childIndex = buildRecursive(nodeIndices: quadrant, depth: depth + 1)
                if childIndex >= 0 {
                    childIndices[i] = Int32(childIndex)
                }
            }
        }
        
        node.children = (childIndices[0], childIndices[1], childIndices[2], childIndices[3])
        nodes.append(node)
        
        return nodeIndex
    }
    
    private func calculateBounds(for indices: [Int]) -> SIMD4<Float> {
        var minX = Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        
        for index in indices {
            if index < leaves.count {
                let node = leaves[index]
                let x = Float(node.graphX)
                let y = Float(node.graphY)
                
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        
        return SIMD4<Float>(minX, minY, maxX, maxY)
    }
    
    private func splitIntoQuadrants(nodeIndices: [Int], bounds: SIMD4<Float>) -> [[Int]] {
        let centerX = (bounds.x + bounds.z) * 0.5
        let centerY = (bounds.y + bounds.w) * 0.5
        
        var quadrants: [[Int]] = [[], [], [], []]
        
        for index in nodeIndices {
            if index < leaves.count {
                let node = leaves[index]
                let x = Float(node.graphX)
                let y = Float(node.graphY)
                
                let quadrant: Int
                if x < centerX {
                    quadrant = y < centerY ? 0 : 2 // Bottom-left or top-left
                } else {
                    quadrant = y < centerY ? 1 : 3 // Bottom-right or top-right
                }
                
                quadrants[quadrant].append(index)
            }
        }
        
        return quadrants
    }
    
    private func intersects(_ a: SIMD4<Float>, _ b: SIMD4<Float>) -> Bool {
        return !(a.z < b.x || a.x > b.z || a.w < b.y || a.y > b.w)
    }
    
    private func pointInBounds(_ position: SIMD2<Double>, _ bounds: SIMD4<Float>) -> Bool {
        let x = Float(position.x)
        let y = Float(position.y)
        return x >= bounds.x && x <= bounds.z && y >= bounds.y && y <= bounds.w
    }
    
    // MARK: - Debug Methods
    
    func printStatistics() {
        print("""
        BVH Statistics:
        - Total nodes: \(totalNodes)
        - Leaf nodes: \(leafNodes)
        - Internal nodes: \(totalNodes - leafNodes)
        - Max depth reached: \(maxDepthReached)
        - Total leaves: \(leaves.count)
        - Average leaf size: \(leafNodes > 0 ? Double(leaves.count) / Double(leafNodes) : 0)
        """)
    }
    
    func validateTree() -> Bool {
        guard !nodes.isEmpty else { return true }
        
        return validateNode(index: 0, depth: 0)
    }
    
    private func validateNode(index: Int, depth: Int) -> Bool {
        guard index >= 0 && index < nodes.count else { return false }
        
        let node = nodes[index]
        
        if node.isLeaf {
            // Validate leaf node
            let start = Int(node.leafOffset)
            let end = start + Int(node.leafCount)
            return start >= 0 && end <= leaves.count
        } else {
            // Validate internal node and recurse
            var hasValidChild = false
            
            if node.children.0 >= 0 {
                hasValidChild = true
                if !validateNode(index: Int(node.children.0), depth: depth + 1) {
                    return false
                }
            }
            
            if node.children.1 >= 0 {
                hasValidChild = true
                if !validateNode(index: Int(node.children.1), depth: depth + 1) {
                    return false
                }
            }
            
            if node.children.2 >= 0 {
                hasValidChild = true
                if !validateNode(index: Int(node.children.2), depth: depth + 1) {
                    return false
                }
            }
            
            if node.children.3 >= 0 {
                hasValidChild = true
                if !validateNode(index: Int(node.children.3), depth: depth + 1) {
                    return false
                }
            }
            
            return hasValidChild
        }
    }
}

// MARK: - Performance Extensions
extension BVHTree {
    
    /// Get memory usage in bytes
    var memoryUsage: Int {
        return nodes.count * MemoryLayout<Node>.stride + 
               leaves.count * MemoryLayout<FileNode>.stride
    }
    
    /// Get tree depth
    var depth: Int {
        return maxDepthReached
    }
    
    /// Get balance factor (0.0 = perfectly balanced, 1.0 = completely unbalanced)
    var balanceFactor: Double {
        guard totalNodes > 1 else { return 0.0 }
        
        let idealDepth = log2(Double(totalNodes))
        let actualDepth = Double(maxDepthReached)
        
        return min(1.0, (actualDepth - idealDepth) / idealDepth)
    }
}