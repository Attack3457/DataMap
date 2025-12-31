# DataMap (GeoMapper Pro) - Design Specification

## Overview
DataMap transforms file system navigation into an immersive geographic exploration experience. By mapping files and folders to deterministic coordinates, users build spatial memory of their data organization.

## Design Philosophy

### Spatial Metaphors
- **Root Folders** → Continents (major landmasses)
- **Sub-folders** → Countries/States (regional boundaries)
- **Files** → Buildings/POIs (specific locations)
- **File Size** → Building height/prominence
- **File Type** → Architectural style/color coding

### Visual Hierarchy
```
Zoom Level    | Shows                    | Max Nodes | Icon Scale
------------- | ------------------------ | --------- | ----------
Continent     | Major directories only   | 100       | 0.3x
Country       | All top-level dirs       | 500       | 0.4x
Region        | Directory hierarchies    | 1000      | 0.5x
City          | Dirs + large files       | 2000      | 0.7x
District      | All dirs + files >10MB   | 3000      | 0.9x
Street        | All files and dirs       | 5000      | 1.0x
Building      | Maximum detail + labels  | 10000     | 1.2x
```

## User Interface Design

### Map Explorer View
- **Primary Interface**: Full-screen MapKit view with custom annotations
- **Zoom Controls**: Floating action buttons (zoom in/out, reset, grid, info)
- **Search Header**: Persistent search bar with filters and settings
- **Node Details**: Bottom sheet with file information and actions
- **Performance Stats**: Real-time visible node count and frame time

### Annotation Design
- **Circular Icons**: Color-coded by file type with system symbols
- **Size Scaling**: Based on zoom level and content importance
- **Labels**: Contextual display based on zoom level
- **Children Indicators**: Badge showing folder contents count
- **Selection State**: Pulsing animation and enhanced shadow

### Color Coding
```swift
Directory:     Blue (#007AFF)
Swift Files:   Orange (#FF9500)
Text Files:    Green (#34C759)
Images:        Purple (#AF52DE)
Audio:         Pink (#FF2D92)
Video:         Red (#FF3B30)
Archives:      Gray (#8E8E93)
```

## Interaction Design

### Navigation Patterns
1. **Tap to Select**: Show details card with file information
2. **Double-tap to Navigate**: Center and zoom to selected node
3. **Pinch to Zoom**: Smooth zoom with level transitions
4. **Search to Find**: Instant navigation to matching files
5. **Filter by Type**: Toggle directory-only view

### Gestures
- **Single Tap**: Select node, show details
- **Double Tap**: Navigate to node location
- **Long Press**: Context menu (bookmark, tag, share)
- **Pinch**: Zoom in/out with smooth transitions
- **Pan**: Navigate around the map

### Animations
- **Zoom Transitions**: Smooth scaling with icon size adjustments
- **Node Selection**: Pulsing effect with shadow enhancement
- **Loading States**: Progress indicators with file count updates
- **Navigation**: Smooth camera movements with easing

## Performance Considerations

### Rendering Optimization
- **Viewport Culling**: Only render nodes within visible region
- **Level-of-Detail**: Reduce complexity at higher zoom levels
- **Node Limiting**: Maximum visible nodes per zoom level
- **Batch Updates**: Throttle updates during user interaction

### Memory Management
- **Lazy Loading**: Load node details on demand
- **Cache Management**: LRU cache for coordinate calculations
- **Background Processing**: File scanning on background actors
- **SwiftData Integration**: Persistent storage with efficient queries

## Accessibility

### VoiceOver Support
- **Node Descriptions**: "Folder: Documents, contains 45 items"
- **Location Context**: "Located in North America region"
- **Action Hints**: "Double-tap to navigate to this location"

### Dynamic Type
- **Scalable Text**: All labels support Dynamic Type
- **Icon Scaling**: Annotations scale with accessibility settings
- **High Contrast**: Enhanced colors for better visibility

### Reduced Motion
- **Static Alternatives**: Disable pulsing animations
- **Instant Transitions**: Replace smooth animations with cuts
- **Simplified UI**: Reduce visual complexity

## Error Handling

### File System Errors
- **Permission Denied**: Clear message with resolution steps
- **File Not Found**: Graceful degradation with placeholder
- **Scan Failures**: Partial results with error indicators
- **Memory Limits**: Progressive loading with warnings

### User Feedback
- **Loading States**: Progress bars with descriptive text
- **Error Alerts**: Actionable error messages
- **Success Indicators**: Confirmation of completed actions
- **Performance Warnings**: Alerts for large datasets

## Future Enhancements

### Advanced Features
- **Metal Rendering**: GPU-accelerated map rendering
- **BVH Spatial Indexing**: O(log n) spatial queries
- **Custom Map Styles**: Satellite, terrain, hybrid views
- **Collaborative Features**: Shared maps and annotations
- **Export Options**: Share map views and coordinates

### Platform Extensions
- **macOS Version**: Desktop file system exploration
- **iPad Optimization**: Split-view and multi-window support
- **Apple Watch**: Quick file location lookup
- **Shortcuts Integration**: Siri voice commands

## Technical Architecture

### Data Flow
```
FileSystem → Scanner → CoordinateEngine → GeoNode → SwiftData
                                      ↓
                              MapExplorerView → Annotations
```

### Component Responsibilities
- **Scanner**: Async file system traversal
- **CoordinateEngine**: Deterministic coordinate generation
- **GeoNode**: SwiftData model with spatial properties
- **MapExplorerView**: Primary UI with zoom management
- **ViewModel**: State management and business logic

### Performance Targets
- **Scan Speed**: 1000+ files/second
- **Render Rate**: 60 FPS at all zoom levels
- **Memory Usage**: <100MB for 10K nodes
- **Startup Time**: <2 seconds to first map view
- **Search Response**: <100ms for text queries