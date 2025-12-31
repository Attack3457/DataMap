# Implementation Plan: GeoMapper Pro (Advanced Metal/BVH)

## Overview

This implementation plan builds GeoMapper Pro with GPU-accelerated Metal rendering, BVH spatial indexing, and lock-free BSD syscall-based file scanning. Tasks are ordered to build core utilities first, then spatial data structures, followed by the rendering pipeline.

## Tasks

- [ ] 1. Set up project structure and dependencies
  - Create folder structure: `Engine/`, `Spatial/`, `Scanner/`, `Rendering/`, `ViewModels/`
  - Add SwiftCheck package dependency for property-based testing
  - Add CryptoKit import for SHA3 hashing
  - Configure Metal shader compilation in build settings
  - _Requirements: 7.1_

- [ ] 2. Implement core data types
  - [ ] 2.1 Create UInt128 and SpatialID types
    - Implement `UInt128` struct with high/low UInt64 components
    - Implement `SpatialID` struct for 128-bit spatial identifiers
    - Add bitwise operations for Morton code manipulation
    - _Requirements: 1.1_

  - [ ] 2.2 Create FileNode struct
    - Implement with `id: SpatialID`, `position: SIMD2<Float>`, `size: Float`
    - Add `color: SIMD4<Float>`, `inode: UInt64`, `depth: UInt8`, `flags: UInt8`
    - Conform to `Sendable` for actor isolation
    - _Requirements: 6.1, 6.3, 6.4, 6.5, 6.6_

  - [ ] 2.3 Write property tests for FileNode
    - **Property 7: FileNode ID Uniqueness**
    - **Validates: Requirements 6.1**

- [ ] 3. Implement GeoHashEngine
  - [ ] 3.1 Create GeoHashEngine with SHA3-512 hashing
    - Implement `hashPath(_:) -> SpatialID` using CryptoKit SHA3
    - Extract 128-bit Morton code from hash digest
    - Add `@_transparent` and `@_optimize(speed)` attributes
    - _Requirements: 1.1, 1.2_

  - [ ] 3.2 Implement coordinate generation
    - Implement `coordinate(for:) -> SIMD2<Float>` method
    - Add Morton-to-latitude and Morton-to-longitude conversions
    - Use spherical Fibonacci lattice for uniform distribution
    - Add `@_alwaysEmitIntoClient` for inlining
    - _Requirements: 1.1, 1.4_

  - [ ] 3.3 Write property tests for GeoHashEngine
    - **Property 1: Hash Determinism**
    - **Property 2: Coordinate Determinism**
    - **Property 3: Coordinate Bounds Invariant**
    - **Validates: Requirements 1.1, 1.2, 1.4**

- [ ] 4. Checkpoint - Hash engine complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement GeoMemoryManager
  - [ ] 5.1 Create arena-based memory allocator
    - Implement 50MB pre-allocated arena with `UnsafeMutableRawBufferPointer`
    - Implement `allocate<T>(count:) -> UnsafeMutableBufferPointer<T>`
    - Ensure 64-byte alignment for all allocations
    - Implement `reset()` for arena reuse
    - _Requirements: 8.1_

  - [ ] 5.2 Implement zero-copy FileNode creation
    - Implement `createFileNode(path:inode:) -> FileNode`
    - Integrate with GeoHashEngine for coordinate generation
    - _Requirements: 8.1_

  - [ ] 5.3 Write property tests for GeoMemoryManager
    - **Property 6: Memory Arena Allocation Consistency**
    - **Validates: Requirements 8.1**

- [ ] 6. Implement BVHTree
  - [ ] 6.1 Create BVH node structure
    - Implement internal `Node` struct with `bounds: SIMD4<Float>`
    - Add 4-way children indices and leaf count
    - Configure max depth of 24 levels
    - _Requirements: 5.4, 8.2_

  - [ ] 6.2 Implement BVH build algorithm
    - Implement `build(from nodes:)` method
    - Use surface area heuristic for split decisions
    - Handle leaf threshold of 16 nodes
    - _Requirements: 5.4_

  - [ ] 6.3 Implement SIMD-accelerated query
    - Implement `query(viewport:) -> [FileNode]` with O(log n) complexity
    - Use SIMD4 bounds test (4 comparisons in 1 instruction)
    - Implement stack-based traversal (no recursion)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 8.2_

  - [ ] 6.4 Write property tests for BVHTree
    - **Property 4: BVH Query Correctness**
    - **Property 5: BVH Query Completeness**
    - **Property 9: SIMD Bounds Test Equivalence**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 8.2**

- [ ] 7. Checkpoint - Spatial indexing complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement FileSystemHyperScanner
  - [ ] 8.1 Create actor with BSD syscall scanning
    - Implement actor with file descriptor and 1MB buffer
    - Use `open()` with `O_RDONLY | O_NONBLOCK | O_DIRECTORY`
    - Implement `scan() async throws -> [FileNode]`
    - Use `getdirentries64` syscall for zero-copy reads
    - _Requirements: 3.1, 3.2_

  - [ ] 8.2 Implement SIMD-parallel buffer processing
    - Implement `processBuffer()` with TaskGroup
    - Process 1024 entries in parallel chunks
    - Use `Task.yield()` every 10k files
    - Pre-allocate 1M node capacity
    - _Requirements: 3.3, 3.4, 8.1_

  - [ ] 8.3 Implement error handling
    - Handle POSIX errors gracefully (skip and continue)
    - Wrap errno in `POSIXError`
    - Clean up file descriptors on error/cancellation
    - _Requirements: 3.5_

  - [ ] 8.4 Write property tests for FileSystemHyperScanner
    - **Property 8: Scanner Error Resilience**
    - **Validates: Requirements 3.5**

- [ ] 9. Implement Metal rendering pipeline
  - [ ] 9.1 Create Metal shaders
    - Create `Shaders.metal` file
    - Implement `vertex_main` with billboard rendering
    - Implement `fragment_main` with circle anti-aliasing
    - Define vertex input/output structures
    - _Requirements: 4.2, 4.3, 4.4_

  - [ ] 9.2 Create MetalMapView coordinator
    - Implement `MTKViewDelegate` coordinator
    - Set up `MTLDevice`, `MTLCommandQueue`, `MTLRenderPipelineState`
    - Create vertex buffer from FileNode array
    - Implement `draw(in:)` render loop
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ] 9.3 Create MetalMapView UIViewRepresentable
    - Implement `makeUIView`, `updateUIView`, `makeCoordinator`
    - Bind to GeoEngineViewModel
    - Handle viewport changes for BVH queries
    - _Requirements: 4.1, 4.5_

- [ ] 10. Implement GeoEngineViewModel
  - [ ] 10.1 Create Swift 6 strict concurrency view model
    - Mark with `@MainActor`
    - Add `nonisolated` scanner and memory manager references
    - Implement `@Published` properties: `visibleNodes`, `totalNodes`, `isScanning`, `viewport`
    - _Requirements: 7.1, 7.2_

  - [ ] 10.2 Implement scan coordination
    - Implement `startScan() async` method
    - Coordinate with FileSystemHyperScanner actor
    - Build BVH after scan completes
    - _Requirements: 3.4, 7.4_

  - [ ] 10.3 Implement viewport-based visibility
    - Implement `updateVisibleNodes()` using BVH query
    - Implement `queryViewport(_:) -> [FileNode]`
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ] 11. Checkpoint - Rendering pipeline complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Integration and wiring
  - [ ] 12.1 Create GeoMapperError enum
    - Implement error cases for file descriptor, memory, BVH, Metal, and cancellation
    - Conform to `Error` and `LocalizedError`
    - _Requirements: 3.5_

  - [ ] 12.2 Wire components in main app
    - Update `DataMapApp.swift` to use `MetalMapView`
    - Initialize GeoEngineViewModel with error handling
    - Start initial scan on app launch
    - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ] 12.3 Write integration tests
    - Test end-to-end scan to render flow
    - Test BVH query with real file system data
    - Test Metal rendering initialization
    - _Requirements: 4.5_

- [ ] 13. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tasks are required for the advanced Metal/BVH implementation
- Property tests validate universal correctness properties from the design document
- Uses Swift 5.9+ features: actors, async/await, strict concurrency
- Uses low-level BSD syscalls for maximum performance
- Metal shaders provide GPU-accelerated rendering
- BVH provides O(log n) spatial queries vs O(n) linear filtering
- 50MB memory arena targets efficient memory usage for 1M+ nodes
