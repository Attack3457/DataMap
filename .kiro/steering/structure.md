# Project Structure

```
DataMap/
├── DataMapApp.swift          # App entry point (@main) with SwiftData
├── ContentView.swift         # Root SwiftUI view with welcome screen
├── Assets.xcassets/          # App icons, colors, images
│
├── Views/                    # ✅ Complete SwiftUI view system
│   ├── MainAppLayout.swift   # Adaptive layout (iPad sidebar + iPhone tabs)
│   ├── MapExplorerView.swift # Advanced interactive map with zoom levels
│   ├── MapComponents.swift   # Annotation views and UI components
│   ├── MapSettingsView.swift # Settings and legend views
│   ├── SidebarView.swift     # iPad/Mac sidebar navigation
│   ├── FileBrowserView.swift # Multi-mode file browser (list/grid/hierarchy)
│   ├── ProjectsView.swift    # Project management interface
│   ├── StatisticsView.swift  # Analytics and charts
│   ├── FilterView.swift      # Advanced filtering interface
│   ├── NewProjectView.swift  # Project creation and import/export
│   ├── PerformanceSettingsView.swift # Performance configuration UI
│   ├── OnboardingView.swift  # Welcome and onboarding experience
│   └── UtilityViews.swift    # Supporting components and layouts
│
├── Configuration/            # ✅ Performance and settings
│   ├── PerformanceSettings.swift     # Adaptive performance configuration
│   ├── PerformanceProfileManager.swift # Performance profile management
│   ├── PerformanceMonitor.swift      # Real-time performance monitoring
│   └── EnhancedPerformanceMonitor.swift # Advanced performance tracking
│
├── Analytics/                # ✅ Privacy-friendly analytics
│   └── AnalyticsManager.swift # GDPR-compliant analytics and crash reporting
│
├── Localization/             # ✅ Multi-language support
│   └── LocalizedStrings.swift # Localized strings and formatting
│
├── Rendering/                # ✅ Metal GPU rendering
│   ├── MetalRenderer.swift   # Metal-based GPU accelerated rendering
│   └── Shaders.metal         # GPU shaders for node rendering
│
├── Spatial/                  # ✅ Advanced spatial data structures
│   ├── BVHTree.swift         # Bounding Volume Hierarchy for O(log n) queries
│   └── Octree.swift          # Octree spatial indexing
│
├── Engine/                   # ✅ Enhanced coordinate engines
│   ├── CoordinateEngine.swift # Deterministic coordinate generation
│   └── GeoHashEngine.swift   # Advanced spatial hashing with Morton ordering
│
├── Scanner/                  # ✅ High-performance file scanning
│   ├── FileSystemHyperScanner.swift # Actor-based async scanner
│   ├── FileSystemScanner.swift      # Enhanced scanner with statistics
│   └── LowLevelFileScanner.swift    # Direct system call scanner with zero-copy
├── Models/                   # ✅ SwiftData models
│   ├── FileNode.swift        # GeoNode with SwiftData persistence
│   ├── Project.swift         # Project organization model
│   ├── FileSystemItem.swift  # File system bridge struct
│   └── GeoMapperError.swift  # Error types
│
├── Scanner/                  # ✅ File system scanning
│   ├── FileSystemHyperScanner.swift # Actor-based async scanner
│   └── FileSystemScanner.swift      # Enhanced scanner with statistics
│
├── ViewModels/               # ✅ MVVM view models
│   └── GeoEngineViewModel.swift # Enhanced state management with filtering
│
├── Spatial/                  # 📋 Planned spatial data structures
│   ├── BVHTree.swift         # Bounding Volume Hierarchy
│   └── GeoMemoryManager.swift # Arena-based memory allocation
│
└── Rendering/                # 📋 Planned Metal rendering
    ├── MetalMapView.swift    # UIViewRepresentable for Metal
    └── Shaders.metal         # GPU shaders

DataMap.xcodeproj/            # Xcode project configuration
.kiro/
├── steering/                 # AI assistant guidance
│   ├── product.md           # Product overview and status
│   ├── structure.md         # This file - project structure
│   └── tech.md              # Technical specifications
└── specs/                    # Feature specifications
    └── geomapper-pro/
        ├── design.md         # UI/UX design specification
        ├── requirements.md   # Functional requirements
        └── tasks.md          # Task breakdown and progress
```

## Implementation Status

### ✅ Completed Components
- **MainAppLayout.swift**: Professional adaptive layout system
- **SidebarView.swift**: iPad/Mac three-column navigation
- **FileBrowserView.swift**: Multi-mode file browser with table/grid/hierarchy views
- **ProjectsView.swift**: Complete project management with CRUD operations
- **StatisticsView.swift**: Analytics dashboard with charts and metrics
- **FilterView.swift**: Advanced filtering with size, date, and tag filters
- **NewProjectView.swift**: Project creation and import/export workflows
- **UtilityViews.swift**: Supporting components and detail views
- **Enhanced GeoEngineViewModel**: Advanced filtering and search capabilities
- **FileSystemScanner.swift**: Statistics tracking and performance monitoring

### 🚧 Recently Completed Major Features
- **Adaptive UI**: Seamless iPad (sidebar) and iPhone (tabs) layouts
- **Multi-mode File Browser**: List, grid, and hierarchy view modes
- **Advanced Filtering**: Real-time search with size, date, and tag filters
- **Project Management**: Full CRUD operations with SwiftData persistence
- **Statistics Dashboard**: Comprehensive analytics and visualizations
- **Professional Toolbar**: Context-sensitive actions and view controls

### 📋 Architecture Highlights
- **Responsive Design**: Adapts to device capabilities (iPad vs iPhone)
- **Performance Optimized**: Viewport culling, lazy loading, efficient rendering
- **Accessibility Ready**: VoiceOver support, Dynamic Type, keyboard navigation
- **Data Persistence**: SwiftData integration with relationships and queries
- **Modern SwiftUI**: Latest APIs, proper state management, reactive updates

## Key Features Implemented

### **Professional UI System**
- **Adaptive Layout**: NavigationSplitView for iPad, TabView for iPhone
- **Sidebar Navigation**: Project browser, recent scans, tags, and quick actions
- **Multi-Column Layout**: Sidebar → Content → Detail (iPad)
- **Context Menus**: Right-click actions throughout the interface
- **Toolbar Integration**: Platform-appropriate controls and actions

### **Advanced File Management**
- **Multiple View Modes**: Table view, grid view, hierarchy view
- **Bulk Operations**: Multi-select with batch actions
- **Advanced Filtering**: Size ranges, date ranges, tag-based filtering
- **Real-time Search**: Debounced search with instant results
- **Export/Import**: JSON export, file sharing, project backup

### **Data Visualization**
- **Statistics Dashboard**: File type distribution, size analysis
- **Interactive Charts**: Visual representation of file system data
- **Performance Metrics**: Scan statistics, memory usage, processing speed
- **Activity Tracking**: Recent file modifications and access patterns

## Conventions
- **Modular Architecture**: Each view in separate file for maintainability
- **Consistent Naming**: Clear, descriptive component names
- **SwiftUI Best Practices**: Proper state management, view composition
- **Performance Focus**: Lazy loading, efficient data structures
- **Accessibility First**: Built-in support for assistive technologies
- **Platform Adaptive**: Leverages device capabilities appropriately
