// 📁 File: Engine/GraphLayoutEngine.swift
// 🎯 FORCE-DIRECTED GRAPH LAYOUT FOR FILE SYSTEM

import Foundation
import simd

// MARK: - Graph Layout Protocol
public protocol GraphLayoutEngineProtocol: Sendable {
    func layout(for nodes: [FileNode], edges: [FileEdge]) async -> [GraphPosition]
    func updateLayout() async
    func reset() async
}

// MARK: - Force-Directed Layout Engine
public actor ForceDirectedLayoutEngine: GraphLayoutEngineProtocol {
    
    // MARK: - Configuration
    public struct Configuration: Sendable {
        var repulsionStrength: Double = 100.0
        var attractionStrength: Double = 0.1
        var springLength: Double = 50.0
        var damping: Double = 0.8
        var maxIterations: Int = 500
        var tolerance: Double = 0.001
        var enableBarnesHut: Bool = true
        var theta: Double = 0.5
        
        public static let `default` = Configuration()
    }
    
    // MARK: - Properties
    private let configuration: Configuration
    private var positions: [String: SIMD2<Double>] = [:]
    private var velocities: [String: SIMD2<Double>] = [:]
    private var masses: [String: Double] = [:]
    private var edges: [FileEdge] = []
    
    // Barnes-Hut tree for O(n log n) performance
    private var barnesHutTree: QuadTree?
    
    // MARK: - Initializer
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public API
    
    /// Main layout function
    public func layout(for nodes: [FileNode], edges: [FileEdge]) async -> [GraphPosition] {
        self.edges = edges
        
        // Initialize positions and velocities
        initializePositions(for: nodes)
        
        // Run force-directed algorithm
        await runForceDirectedLayout()
        
        // Convert to output format
        return positions.map { GraphPosition(id: $0.key, position: $0.value) }
    }
    
    /// Update layout with new nodes/edges
    public func updateLayout() async {
        await runForceDirectedLayout(iterations: 50)
    }
    
    /// Reset layout
    public func reset() async {
        positions.removeAll()
        velocities.removeAll()
        masses.removeAll()
    }
    
    // MARK: - Force Calculation Methods
    
    private func initializePositions(for nodes: [FileNode]) {
        // Start with random positions in a circle
        let center = SIMD2<Double>(0.5, 0.5)
        let radius = 0.4
        
        for node in nodes {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 0...radius)
            let x = center.x + distance * cos(angle)
            let y = center.y + distance * sin(angle)
            
            positions[node.id.uuidString] = SIMD2<Double>(x, y)
            velocities[node.id.uuidString] = SIMD2<Double>(0, 0)
            
            // Mass based on file size or node type
            masses[node.id.uuidString] = calculateMass(for: node)
        }
    }
    
    private func runForceDirectedLayout(iterations: Int? = nil) async {
        let maxIter = iterations ?? configuration.maxIterations
        
        for iteration in 0..<maxIter {
            var totalEnergy: Double = 0.0
            
            // Build Barnes-Hut tree if enabled
            if configuration.enableBarnesHut {
                barnesHutTree = buildBarnesHutTree()
            }
            
            // Calculate forces for each node
            for (nodeId, position) in positions {
                var force = SIMD2<Double>(0, 0)
                
                // Repulsive forces (all nodes)
                force += calculateRepulsiveForce(for: nodeId, at: position)
                
                // Attractive forces (connected edges)
                force += calculateAttractiveForce(for: nodeId, at: position)
                
                // Update velocity and position
                if let velocity = velocities[nodeId], let mass = masses[nodeId] {
                    let acceleration = force / mass
                    let newVelocity = (velocity + acceleration) * configuration.damping
                    let newPosition = position + newVelocity
                    
                    velocities[nodeId] = newVelocity
                    positions[nodeId] = clampPosition(newPosition)
                    
                    // Calculate energy for convergence check
                    totalEnergy += simd_length_squared(newVelocity)
                }
            }
            
            // Check for convergence
            if totalEnergy < configuration.tolerance {
                print("Layout converged after \(iteration) iterations")
                break
            }
            
            // Yield to prevent blocking
            if iteration % 10 == 0 {
                await Task.yield()
            }
        }
    }
    
    private func calculateRepulsiveForce(for nodeId: String, at position: SIMD2<Double>) -> SIMD2<Double> {
        var force = SIMD2<Double>(0, 0)
        
        if configuration.enableBarnesHut, let tree = barnesHutTree {
            // Use Barnes-Hut approximation for O(n log n)
            force = tree.calculateForce(for: nodeId,
                                      at: position,
                                      theta: configuration.theta,
                                      strength: configuration.repulsionStrength)
        } else {
            // Brute force O(n²) - only for small graphs
            for (otherId, otherPos) in positions where otherId != nodeId {
                let delta = position - otherPos
                let distance = simd_length(delta)
                
                // Avoid division by zero
                guard distance > 0.001 else { continue }
                
                // Coulomb's law: F = k * (q1 * q2) / r²
                let repulsion = configuration.repulsionStrength / (distance * distance)
                force += (delta / distance) * repulsion
            }
        }
        
        return force
    }
    
    private func calculateAttractiveForce(for nodeId: String, at position: SIMD2<Double>) -> SIMD2<Double> {
        var force = SIMD2<Double>(0, 0)
        
        for edge in edges where edge.sourceId == nodeId || edge.targetId == nodeId {
            let otherId = edge.sourceId == nodeId ? edge.targetId : edge.sourceId
            guard let otherPos = positions[otherId] else { continue }
            
            let delta = otherPos - position
            let distance = simd_length(delta)
            
            // Hooke's law: F = -k * (r - L)
            let attraction = configuration.attractionStrength * (distance - configuration.springLength)
            force += (delta / distance) * attraction
        }
        
        return force
    }
    
    private func calculateMass(for node: FileNode) -> Double {
        if node.isDirectory {
            return 2.0 + Double(node.children.count) * 0.1
        } else {
            return 1.0 + Double(node.size) / (1024 * 1024) // MB cinsinden
        }
    }
    
    private func clampPosition(_ position: SIMD2<Double>) -> SIMD2<Double> {
        // Keep nodes within reasonable bounds
        let clampedX = min(max(position.x, 0.0), 1.0)
        let clampedY = min(max(position.y, 0.0), 1.0)
        return SIMD2<Double>(clampedX, clampedY)
    }
    
    // MARK: - Barnes-Hut Tree Implementation
    
    private func buildBarnesHutTree() -> QuadTree {
        let bounds = QuadTree.Bounds(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let tree = QuadTree(bounds: bounds, capacity: 10)
        
        for (nodeId, position) in positions {
            let node = QuadTree.QuadNode(id: nodeId,
                              position: position,
                              mass: masses[nodeId] ?? 1.0)
            tree.insert(node)
        }
        
        return tree
    }
}

// MARK: - Supporting Structures

public struct GraphPosition: Identifiable, Sendable {
    public let id: String
    public let position: SIMD2<Double>
    
    public init(id: String, position: SIMD2<Double>) {
        self.id = id
        self.position = position
    }
}

public struct FileEdge: Sendable, Codable {
    public let sourceId: String
    public let targetId: String
    public let strength: Double
    
    public init(sourceId: String, targetId: String, strength: Double = 1.0) {
        self.sourceId = sourceId
        self.targetId = targetId
        self.strength = strength
    }
}

// MARK: - QuadTree for Barnes-Hut Approximation

final class QuadTree {
    struct Bounds {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        
        func contains(_ point: SIMD2<Double>) -> Bool {
            return point.x >= x && point.x <= x + width &&
                   point.y >= y && point.y <= y + height
        }
        
        var centerOfMass: SIMD2<Double> {
            SIMD2<Double>(x + width/2, y + height/2)
        }
    }
    
    struct QuadNode {
        let id: String
        let position: SIMD2<Double>
        let mass: Double
    }
    
    let bounds: Bounds
    let capacity: Int
    var nodes: [QuadNode] = []
    var divided = false
    
    var nw: QuadTree?
    var ne: QuadTree?
    var sw: QuadTree?
    var se: QuadTree?
    
    var centerOfMass: SIMD2<Double> = .zero
    var totalMass: Double = 0.0
    
    init(bounds: Bounds, capacity: Int) {
        self.bounds = bounds
        self.capacity = capacity
    }
    
    func insert(_ node: QuadNode) {
        guard bounds.contains(node.position) else { return }
        
        if nodes.count < capacity && !divided {
            nodes.append(node)
            updateCenterOfMass(with: node)
        } else {
            if !divided {
                subdivide()
            }
            
            // Reinsert existing nodes
            let oldNodes = nodes
            nodes.removeAll()
            for oldNode in oldNodes {
                insert(oldNode)
            }
            
            // Insert new node
            nw?.insert(node)
            ne?.insert(node)
            sw?.insert(node)
            se?.insert(node)
        }
    }
    
    private func subdivide() {
        let x = bounds.x
        let y = bounds.y
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        
        nw = QuadTree(bounds: Bounds(x: x, y: y, width: halfWidth, height: halfHeight),
                     capacity: capacity)
        ne = QuadTree(bounds: Bounds(x: x + halfWidth, y: y, width: halfWidth, height: halfHeight),
                     capacity: capacity)
        sw = QuadTree(bounds: Bounds(x: x, y: y + halfHeight, width: halfWidth, height: halfHeight),
                     capacity: capacity)
        se = QuadTree(bounds: Bounds(x: x + halfWidth, y: y + halfHeight, width: halfWidth, height: halfHeight),
                     capacity: capacity)
        
        divided = true
    }
    
    private func updateCenterOfMass(with node: QuadNode) {
        let newTotalMass = totalMass + node.mass
        centerOfMass = (centerOfMass * totalMass + node.position * node.mass) / newTotalMass
        totalMass = newTotalMass
    }
    
    func calculateForce(for nodeId: String,
                       at position: SIMD2<Double>,
                       theta: Double,
                       strength: Double) -> SIMD2<Double> {
        var force = SIMD2<Double>(0, 0)
        
        let distanceToCenter = simd_length(position - centerOfMass)
        let size = max(bounds.width, bounds.height)
        
        // If node is far enough or this is a leaf node
        if size / distanceToCenter < theta || !divided {
            // Treat as single body
            if totalMass > 0 && !nodes.contains(where: { $0.id == nodeId }) {
                let delta = centerOfMass - position
                let distance = simd_length(delta)
                guard distance > 0.001 else { return .zero }
                
                let repulsion = strength * totalMass / (distance * distance)
                force += (delta / distance) * repulsion
            }
        } else if divided {
            // Recursively compute forces from children
            force += nw?.calculateForce(for: nodeId, at: position, theta: theta, strength: strength) ?? .zero
            force += ne?.calculateForce(for: nodeId, at: position, theta: theta, strength: strength) ?? .zero
            force += sw?.calculateForce(for: nodeId, at: position, theta: theta, strength: strength) ?? .zero
            force += se?.calculateForce(for: nodeId, at: position, theta: theta, strength: strength) ?? .zero
        }
        
        return force
    }
}

// MARK: - Preview Support
extension ForceDirectedLayoutEngine {
    static func previewLayout() async -> [GraphPosition] {
        let engine = ForceDirectedLayoutEngine()
        
        // Create sample nodes
        let rootNode = FileNode(name: "Root", path: "/", nodeType: .directory)
        let docsNode = FileNode(name: "Documents", path: "/Documents", nodeType: .directory)
        let fileNode = FileNode(name: "File.txt", path: "/Documents/File.txt", nodeType: .file, size: 1024)
        let imagesNode = FileNode(name: "Images", path: "/Images", nodeType: .directory)
        let photoNode = FileNode(name: "Photo.jpg", path: "/Images/Photo.jpg", nodeType: .file, size: 1024 * 1024)
        
        let nodes = [rootNode, docsNode, fileNode, imagesNode, photoNode]
        
        let edges = [
            FileEdge(sourceId: rootNode.id.uuidString, targetId: docsNode.id.uuidString),
            FileEdge(sourceId: rootNode.id.uuidString, targetId: imagesNode.id.uuidString),
            FileEdge(sourceId: docsNode.id.uuidString, targetId: fileNode.id.uuidString),
            FileEdge(sourceId: imagesNode.id.uuidString, targetId: photoNode.id.uuidString)
        ]
        
        return await engine.layout(for: nodes, edges: edges)
    }
}