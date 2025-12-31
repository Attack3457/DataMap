# Tech Stack

## Platform & Language
- iOS (iPhone + iPad)
- Swift 5.9+ with strict concurrency
- Minimum deployment: iOS 17.0 (SwiftData requirement)

## Frameworks
- SwiftUI (declarative UI)
- SwiftData (data persistence)
- MapKit (map display and interactions)
- Metal (planned GPU rendering)
- CryptoKit (SHA256 hashing for coordinate generation)
- CoreLocation (CLLocationCoordinate2D)

## Architecture
- MVVM pattern with SwiftUI
- Swift Actors for thread-safe file scanning
- SwiftData for persistent storage
- BVH (Bounding Volume Hierarchy) for O(log n) spatial queries (planned)

## Build System
- Xcode 15.0+
- Swift Package Manager for dependencies
- iOS 17.0+ deployment target

## Dependencies
- SwiftCheck (property-based testing) - planned
- No external dependencies currently

## Current Implementation

### Data Layer
- **SwiftData Models**: GeoNode, Project with relationships
- **Actor-based Scanning**: FileSystemHyperScanner with progress tracking
- **Coordinate Engine**: Deterministic SHA256-based coordinate generation
- **Caching**: In-memory coordinate cache for performance

### UI Layer
- **MapExplorerView**: Advanced map with 7 zoom levels
- **Custom Annotations**: Scalable icons with contextual labels
- **Performance Optimization**: Viewport culling and node limiting
- **Search Integration**: Real-time filtering and navigation

### Performance Features
- **Zoom-level Management**: Dynamic node filtering (100-10K nodes)
- **Viewport Culling**: Only render visible map regions
- **Background Processing**: Async file scanning with cancellation
- **Memory Monitoring**: Real-time performance tracking

## Common Commands

```bash
# Build from command line
xcodebuild -project DataMap.xcodeproj -scheme DataMap -configuration Debug build

# Run tests
xcodebuild -project DataMap.xcodeproj -scheme DataMap test

# Clean build
xcodebuild -project DataMap.xcodeproj -scheme DataMap clean

# Run with Instruments
xcodebuild -project DataMap.xcodeproj -scheme DataMap -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -enableAddressSanitizer YES build
```

## Code Style
- Use `@MainActor` for view models
- Use `nonisolated` for thread-safe utility functions
- Prefer SIMD types for GPU-friendly data (`SIMD2<Float>`, `SIMD4<Float>`)
- Use `@_transparent` and `@_optimize(speed)` for performance-critical code
- Conform data models to `Sendable` for actor isolation
- SwiftData models use `@Model` macro
- Async/await for all file system operations

## Performance Targets
- **Scan Speed**: 1000+ files/second
- **Render Rate**: 60 FPS at all zoom levels
- **Memory Usage**: <100MB for 10K nodes
- **Startup Time**: <2 seconds to first map view
- **Search Response**: <100ms for text queries

## Planned Enhancements

### Metal Rendering Pipeline
- Custom vertex/fragment shaders for node rendering
- GPU-based spatial culling and LOD
- Instanced rendering for large datasets
- Custom map tile rendering

### Spatial Optimization
- BVH tree for O(log n) spatial queries
- Arena-based memory allocation
- Spatial hashing for collision detection
- Efficient nearest-neighbor search

### Testing Strategy
- Unit tests for coordinate generation
- Performance tests for large datasets
- UI tests for map interactions
- Property-based testing with SwiftCheck
