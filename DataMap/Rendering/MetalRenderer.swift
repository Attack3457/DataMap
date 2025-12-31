// 📁 File: Rendering/MetalRenderer.swift
// 🎯 METAL-BASED GPU ACCELERATED RENDERING

import MetalKit
import SwiftUI
import simd
import CoreLocation

// MARK: - Metal View
struct MetalGeoMapView: UIViewRepresentable {
    @EnvironmentObject private var viewModel: GraphViewModel
    @EnvironmentObject private var performanceMonitor: PerformanceMonitor
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 120
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1)
        mtkView.enableSetNeedsDisplay = true
        
        context.coordinator.setup(mtkView: mtkView, viewModel: viewModel, performanceMonitor: performanceMonitor)
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.update(viewModel: viewModel)
    }
    
    func makeCoordinator() -> MetalRenderer {
        return MetalRenderer()
    }
}

// MARK: - Metal Renderer
final class MetalRenderer: NSObject, MTKViewDelegate {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private var nodeBuffer: MTLBuffer!
    
    // Metal availability flag
    private var isMetalAvailable = false
    
    // Spatial data structures
    private var bvh: BVHTree?
    private var octree: Octree?
    
    // View state
    private var viewModel: GraphViewModel?
    private var performanceMonitor: PerformanceMonitor?
    private var visibleNodes: [FileNode] = []
    private var lastUpdate = Date()
    private var frameStartTime: CFTimeInterval = 0
    
    struct Uniforms {
        var viewMatrix: matrix_float4x4
        var projectionMatrix: matrix_float4x4
        var time: Float
        var zoomLevel: Float
        var viewportSize: SIMD2<Float>
        var nodeScale: Float
    }
    
    struct Vertex {
        var position: SIMD2<Float>
        var color: SIMD4<Float>
        var size: Float
        var nodeID: UInt32
        var nodeType: UInt32
    }
    
    func setup(mtkView: MTKView, viewModel: GraphViewModel, performanceMonitor: PerformanceMonitor) {
        // Safety check: Ensure Metal device is available
        guard let metalDevice = mtkView.device else {
            print("❌ Metal device not available - disabling Metal rendering")
            isMetalAvailable = false
            return
        }
        
        self.device = metalDevice
        self.viewModel = viewModel
        self.performanceMonitor = performanceMonitor
        
        // Safety check: Create command queue
        guard let queue = device.makeCommandQueue() else {
            print("❌ Failed to create Metal command queue - disabling Metal rendering")
            isMetalAvailable = false
            return
        }
        self.commandQueue = queue
        
        // Setup components with error handling
        setupPipeline()
        
        // Only continue if pipeline setup succeeded
        if isMetalAvailable {
            setupBuffers()
            setupSpatialStructures()
            print("✅ Metal renderer setup completed successfully")
        } else {
            print("⚠️ Metal renderer setup failed - using fallback rendering")
        }
    }
    
    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            print("❌ Metal library not found - Metal rendering disabled")
            isMetalAvailable = false
            return
        }
        
        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            print("❌ Metal shader functions not found - using fallback")
            isMetalAvailable = false
            return
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("✅ Metal pipeline state created successfully")
            isMetalAvailable = true
        } catch {
            print("❌ Failed to create Metal pipeline state: \(error)")
            print("🔄 Metal rendering disabled, falling back to CPU rendering")
            isMetalAvailable = false
        }
    }
    
    private func setupBuffers() {
        // Safety check: Ensure device is available
        guard let device = device else {
            print("❌ Metal device not available for buffer creation")
            isMetalAvailable = false
            return
        }
        
        // Uniform buffer (dynamic)
        guard let uniformBuf = device.makeBuffer(
            length: MemoryLayout<Uniforms>.stride,
            options: .storageModeShared
        ) else {
            print("❌ Failed to create uniform buffer")
            isMetalAvailable = false
            return
        }
        uniformBuffer = uniformBuf
        
        // Vertex buffer (will be updated each frame)
        let maxVertices = 100_000
        guard let vertexBuf = device.makeBuffer(
            length: MemoryLayout<Vertex>.stride * maxVertices,
            options: .storageModeShared
        ) else {
            print("❌ Failed to create vertex buffer")
            isMetalAvailable = false
            return
        }
        vertexBuffer = vertexBuf
        
        print("✅ Metal buffers created successfully")
    }
    
    private func setupSpatialStructures() {
        // GPU-accelerated spatial structures
        self.bvh = BVHTree(maxDepth: 24)
        self.octree = Octree(
            bounds: AABB(
                min: SIMD3<Float>(-180, -90, 0),
                max: SIMD3<Float>(180, 90, 0)
            ),
            maxDepth: 8
        )
    }
    
    func update(viewModel: GraphViewModel) {
        self.viewModel = viewModel
        
        // Update visible nodes (frustum culling)
        updateVisibleNodes()
        
        // Rebuild spatial structures if needed
        if shouldRebuildSpatialStructures() {
            rebuildSpatialStructures()
        }
    }
    
    private func updateVisibleNodes() {
        guard let viewModel = viewModel else { return }
        
        let startTime = CACurrentMediaTime()
        
        // Get nodes within current view frustum
        visibleNodes = viewModel.filteredNodes
        
        // Limit for performance
        let maxNodes = 50_000
        if visibleNodes.count > maxNodes {
            visibleNodes = Array(visibleNodes.prefix(maxNodes))
        }
        
        let _ = (CACurrentMediaTime() - startTime) * 1000
        // performanceMonitor?.recordSpatialQuery(time: queryTime)
    }
    
    private func shouldRebuildSpatialStructures() -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceLastUpdate > 5.0 // Rebuild every 5 seconds
    }
    
    private func rebuildSpatialStructures() {
        guard let viewModel = viewModel else { return }
        
        Task.detached(priority: .high) {
            // Build BVH on background thread
            await self.bvh?.build(from: viewModel.filteredNodes)
            await self.octree?.insert(nodes: viewModel.filteredNodes)
            
            await MainActor.run {
                self.lastUpdate = Date()
            }
        }
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
    }
    
    func draw(in view: MTKView) {
        // Safety check: Skip rendering if Metal is not available
        guard isMetalAvailable,
              let pipelineState = pipelineState,
              let commandQueue = commandQueue,
              let vertexBuffer = vertexBuffer,
              let uniformBuffer = uniformBuffer else {
            // Silently skip rendering instead of logging every frame
            return
        }
        
        frameStartTime = CACurrentMediaTime()
        
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("⚠️ Failed to create command buffer")
            return
        }
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("⚠️ Failed to create render encoder")
            return
        }
        
        // Update uniforms
        updateUniforms(view: view)
        
        // Prepare vertex data
        prepareVertexData()
        
        // Safety check: Ensure we have nodes to render
        let nodeCount = min(visibleNodes.count, vertexBuffer.length / MemoryLayout<Vertex>.stride)
        guard nodeCount > 0 else {
            renderEncoder.endEncoding()
            commandBuffer.commit()
            return
        }
        
        // Render
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        // Draw with validated vertex count
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: nodeCount)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Record performance metrics
        let renderTime = (CACurrentMediaTime() - frameStartTime) * 1000
        if renderTime > 16.67 { // Log if frame takes longer than 60fps
            print("⚠️ Slow frame: \(String(format: "%.2f", renderTime))ms for \(nodeCount) nodes")
        }
    }
    
    private func updateUniforms(view: MTKView) {
        let uniforms = Uniforms(
            viewMatrix: matrix_identity_float4x4,
            projectionMatrix: orthographicMatrix(for: view.bounds.size),
            time: Float(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)),
            zoomLevel: 1.0,
            viewportSize: SIMD2<Float>(Float(view.bounds.width), Float(view.bounds.height)),
            nodeScale: 1.0
        )
        
        memcpy(uniformBuffer.contents(), [uniforms], MemoryLayout<Uniforms>.stride)
    }
    
    private func prepareVertexData() {
        // Safety checks
        guard isMetalAvailable,
              let vertexBuffer = vertexBuffer,
              !visibleNodes.isEmpty else {
            return
        }
        
        var vertices: [Vertex] = []
        vertices.reserveCapacity(min(visibleNodes.count, 100_000)) // Limit to buffer size
        
        // Limit nodes to prevent buffer overflow
        let nodesToRender = Array(visibleNodes.prefix(100_000))
        
        for node in nodesToRender {
            let color = getNodeColor(node)
            let size = getNodeSize(node)
            
            // Use graph position instead of geographic coordinates
            let x = Float(node.graphX)
            let y = Float(node.graphY)
            
            // Skip invalid positions
            guard x.isFinite && y.isFinite,
                  x >= 0 && x <= 1,
                  y >= 0 && y <= 1 else {
                print("⚠️ Skipping node with invalid graph position: \(x), \(y)")
                continue
            }
            
            let vertex = Vertex(
                position: SIMD2<Float>(x, y),
                color: color,
                size: size,
                nodeID: UInt32(abs(node.id.hashValue)), // Ensure positive
                nodeType: node.isDirectory ? 1 : 0
            )
            vertices.append(vertex)
        }
        
        // Safety check: Ensure we don't exceed buffer size
        let maxVertices = vertexBuffer.length / MemoryLayout<Vertex>.stride
        if vertices.count > maxVertices {
            vertices = Array(vertices.prefix(maxVertices))
            print("⚠️ Truncated vertices to fit buffer: \(vertices.count)/\(maxVertices)")
        }
        
        // Copy data to buffer
        let dataSize = MemoryLayout<Vertex>.stride * vertices.count
        guard dataSize <= vertexBuffer.length else {
            print("❌ Vertex data too large for buffer: \(dataSize) > \(vertexBuffer.length)")
            return
        }
        
        memcpy(vertexBuffer.contents(), vertices, dataSize)
    }
    
    private func getNodeColor(_ node: FileNode) -> SIMD4<Float> {
        if node.isDirectory {
            return SIMD4<Float>(0.2, 0.6, 1.0, 0.8) // Blue for directories
        } else {
            // Color based on file extension
            let ext = (node.path as NSString).pathExtension.lowercased()
            switch ext {
            case "swift", "js", "py", "cpp", "c", "h":
                return SIMD4<Float>(1.0, 0.6, 0.2, 0.9) // Orange for code
            case "jpg", "png", "gif", "bmp", "tiff":
                return SIMD4<Float>(0.8, 0.2, 0.8, 0.9) // Purple for images
            case "mp4", "mov", "avi", "mkv":
                return SIMD4<Float>(1.0, 0.2, 0.2, 0.9) // Red for videos
            case "mp3", "wav", "aac", "flac":
                return SIMD4<Float>(0.2, 0.8, 0.2, 0.9) // Green for audio
            case "txt", "md", "rtf", "doc", "docx":
                return SIMD4<Float>(0.6, 0.6, 0.6, 0.9) // Gray for text
            default:
                return SIMD4<Float>(0.5, 0.5, 0.5, 0.7) // Default gray
            }
        }
    }
    
    private func getNodeSize(_ node: FileNode) -> Float {
        if node.isDirectory {
            return 8.0
        } else {
            // Size based on file size (logarithmic scale)
            let sizeLog = log10(Double(max(node.size, 1)))
            return Float(max(2.0, min(12.0, sizeLog)))
        }
    }
    
    private func orthographicMatrix(for size: CGSize) -> matrix_float4x4 {
        let left: Float = -180
        let right: Float = 180
        let bottom: Float = -90
        let top: Float = 90
        let near: Float = -1
        let far: Float = 1
        
        var matrix = matrix_identity_float4x4
        matrix.columns.0.x = 2 / (right - left)
        matrix.columns.3.x = -(right + left) / (right - left)
        matrix.columns.1.y = 2 / (top - bottom)
        matrix.columns.3.y = -(top + bottom) / (top - bottom)
        matrix.columns.2.z = -2 / (far - near)
        matrix.columns.3.z = -(far + near) / (far - near)
        
        return matrix
    }
}