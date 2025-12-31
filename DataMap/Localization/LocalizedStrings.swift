// 📁 File: Localization/LocalizedStrings.swift
// 🎯 LOCALIZATION STRINGS

import Foundation

enum LocalizedStrings {
    
    // MARK: - App Information
    static let appName = NSLocalizedString("DataMap Pro", comment: "App name")
    static let appTagline = NSLocalizedString("Visualize your file system as an interactive world map", comment: "App tagline")
    static let appDescription = NSLocalizedString("Transform your files and folders into an immersive geographic experience", comment: "App description")
    
    // MARK: - Main Features
    static let feature1Title = NSLocalizedString("3D File Visualization", comment: "Feature 1 title")
    static let feature1Description = NSLocalizedString("See your entire file system as a beautiful interactive globe", comment: "Feature 1 description")
    
    static let feature2Title = NSLocalizedString("Real-time Scanning", comment: "Feature 2 title")
    static let feature2Description = NSLocalizedString("Scan thousands of files in seconds with GPU acceleration", comment: "Feature 2 description")
    
    static let feature3Title = NSLocalizedString("Smart Search", comment: "Feature 3 title")
    static let feature3Description = NSLocalizedString("Instantly find files with spatial search and filtering", comment: "Feature 3 description")
    
    static let feature4Title = NSLocalizedString("Performance Optimized", comment: "Feature 4 title")
    static let feature4Description = NSLocalizedString("Adaptive quality and Metal rendering for smooth experience", comment: "Feature 4 description")
    
    // MARK: - Navigation
    static let mapTab = NSLocalizedString("Map", comment: "Map tab")
    static let browserTab = NSLocalizedString("Browser", comment: "Browser tab")
    static let projectsTab = NSLocalizedString("Projects", comment: "Projects tab")
    static let statisticsTab = NSLocalizedString("Statistics", comment: "Statistics tab")
    static let settingsTab = NSLocalizedString("Settings", comment: "Settings tab")
    
    // MARK: - Map Interface
    static let zoomIn = NSLocalizedString("Zoom In", comment: "Zoom in button")
    static let zoomOut = NSLocalizedString("Zoom Out", comment: "Zoom out button")
    static let resetView = NSLocalizedString("Reset View", comment: "Reset view button")
    static let showGrid = NSLocalizedString("Show Grid", comment: "Show grid toggle")
    static let showLabels = NSLocalizedString("Show Labels", comment: "Show labels toggle")
    
    // MARK: - File Operations
    static let scanDirectory = NSLocalizedString("Scan Directory", comment: "Scan directory button")
    static let scanningFiles = NSLocalizedString("Scanning Files...", comment: "Scanning progress")
    static let scanComplete = NSLocalizedString("Scan Complete", comment: "Scan completion message")
    static let scanCancelled = NSLocalizedString("Scan Cancelled", comment: "Scan cancellation message")
    
    // MARK: - Search
    static let searchPlaceholder = NSLocalizedString("Search files and folders...", comment: "Search placeholder")
    static let searchResults = NSLocalizedString("Search Results", comment: "Search results title")
    static let noResults = NSLocalizedString("No results found", comment: "No search results")
    static let clearSearch = NSLocalizedString("Clear Search", comment: "Clear search button")
    
    // MARK: - Filters
    static let filters = NSLocalizedString("Filters", comment: "Filters title")
    static let showOnlyDirectories = NSLocalizedString("Show Only Directories", comment: "Directory filter")
    static let fileSize = NSLocalizedString("File Size", comment: "File size filter")
    static let dateModified = NSLocalizedString("Date Modified", comment: "Date filter")
    static let fileType = NSLocalizedString("File Type", comment: "File type filter")
    static let clearFilters = NSLocalizedString("Clear All", comment: "Clear filters button")
    static let applyFilters = NSLocalizedString("Apply", comment: "Apply filters button")
    
    // MARK: - Projects
    static let newProject = NSLocalizedString("New Project", comment: "New project button")
    static let projectName = NSLocalizedString("Project Name", comment: "Project name field")
    static let projectDescription = NSLocalizedString("Description", comment: "Project description field")
    static let createProject = NSLocalizedString("Create", comment: "Create project button")
    static let editProject = NSLocalizedString("Edit", comment: "Edit project button")
    static let deleteProject = NSLocalizedString("Delete", comment: "Delete project button")
    static let exportProject = NSLocalizedString("Export", comment: "Export project button")
    static let importProject = NSLocalizedString("Import", comment: "Import project button")
    
    // MARK: - Statistics
    static let totalFiles = NSLocalizedString("Total Files", comment: "Total files statistic")
    static let totalFolders = NSLocalizedString("Total Folders", comment: "Total folders statistic")
    static let totalSize = NSLocalizedString("Total Size", comment: "Total size statistic")
    static let scanDuration = NSLocalizedString("Scan Duration", comment: "Scan duration statistic")
    static let filesPerSecond = NSLocalizedString("Files/Second", comment: "Files per second statistic")
    
    // MARK: - Performance
    static let performance = NSLocalizedString("Performance", comment: "Performance title")
    static let frameRate = NSLocalizedString("Frame Rate", comment: "Frame rate metric")
    static let memoryUsage = NSLocalizedString("Memory Usage", comment: "Memory usage metric")
    static let cpuUsage = NSLocalizedString("CPU Usage", comment: "CPU usage metric")
    static let cacheHitRate = NSLocalizedString("Cache Hit Rate", comment: "Cache hit rate metric")
    static let qualityLevel = NSLocalizedString("Quality Level", comment: "Quality level setting")
    static let targetFrameRate = NSLocalizedString("Target Frame Rate", comment: "Target frame rate setting")
    
    // MARK: - Settings
    static let generalSettings = NSLocalizedString("General", comment: "General settings")
    static let performanceSettings = NSLocalizedString("Performance", comment: "Performance settings")
    static let privacySettings = NSLocalizedString("Privacy", comment: "Privacy settings")
    static let aboutSettings = NSLocalizedString("About", comment: "About settings")
    
    static let enableAnalytics = NSLocalizedString("Enable Analytics", comment: "Enable analytics toggle")
    static let enableCrashReporting = NSLocalizedString("Enable Crash Reporting", comment: "Enable crash reporting toggle")
    static let enablePerformanceTracking = NSLocalizedString("Enable Performance Tracking", comment: "Enable performance tracking toggle")
    
    // MARK: - Quality Levels
    static let powerSaving = NSLocalizedString("Power Saving", comment: "Power saving quality")
    static let balanced = NSLocalizedString("Balanced", comment: "Balanced quality")
    static let quality = NSLocalizedString("Quality", comment: "Quality mode")
    static let ultra = NSLocalizedString("Ultra", comment: "Ultra quality")
    
    // MARK: - Zoom Levels
    static let continentLevel = NSLocalizedString("Continent", comment: "Continent zoom level")
    static let countryLevel = NSLocalizedString("Country", comment: "Country zoom level")
    static let regionLevel = NSLocalizedString("Region", comment: "Region zoom level")
    static let cityLevel = NSLocalizedString("City", comment: "City zoom level")
    static let districtLevel = NSLocalizedString("District", comment: "District zoom level")
    static let streetLevel = NSLocalizedString("Street", comment: "Street zoom level")
    static let buildingLevel = NSLocalizedString("Building", comment: "Building zoom level")
    
    // MARK: - File Types
    static let directory = NSLocalizedString("Directory", comment: "Directory file type")
    static let file = NSLocalizedString("File", comment: "File type")
    static let symbolicLink = NSLocalizedString("Symbolic Link", comment: "Symbolic link type")
    static let codeFiles = NSLocalizedString("Code Files", comment: "Code files category")
    static let imageFiles = NSLocalizedString("Images", comment: "Image files category")
    static let videoFiles = NSLocalizedString("Videos", comment: "Video files category")
    static let audioFiles = NSLocalizedString("Audio", comment: "Audio files category")
    static let documentFiles = NSLocalizedString("Documents", comment: "Document files category")
    
    // MARK: - Error Messages
    static let errorTitle = NSLocalizedString("Error", comment: "Error dialog title")
    static let scanError = NSLocalizedString("Failed to scan directory", comment: "Scan error message")
    static let permissionError = NSLocalizedString("Permission denied", comment: "Permission error message")
    static let memoryError = NSLocalizedString("Insufficient memory", comment: "Memory error message")
    static let unknownError = NSLocalizedString("An unknown error occurred", comment: "Unknown error message")
    
    // MARK: - Alerts
    static let confirmDelete = NSLocalizedString("Are you sure you want to delete this project?", comment: "Delete confirmation")
    static let confirmClearData = NSLocalizedString("This will clear all analytics data. Continue?", comment: "Clear data confirmation")
    static let confirmReset = NSLocalizedString("Reset all settings to default?", comment: "Reset confirmation")
    
    // MARK: - Actions
    static let ok = NSLocalizedString("OK", comment: "OK button")
    static let cancel = NSLocalizedString("Cancel", comment: "Cancel button")
    static let delete = NSLocalizedString("Delete", comment: "Delete button")
    static let save = NSLocalizedString("Save", comment: "Save button")
    static let done = NSLocalizedString("Done", comment: "Done button")
    static let retry = NSLocalizedString("Retry", comment: "Retry button")
    static let close = NSLocalizedString("Close", comment: "Close button")
    
    // MARK: - Privacy
    static let privacyPolicy = NSLocalizedString("Privacy Policy", comment: "Privacy policy title")
    static let dataCollection = NSLocalizedString("Data Collection", comment: "Data collection section")
    static let yourRights = NSLocalizedString("Your Rights", comment: "Your rights section")
    static let contactUs = NSLocalizedString("Contact Us", comment: "Contact us section")
    
    // MARK: - Onboarding
    static let welcomeTitle = NSLocalizedString("Welcome to DataMap Pro", comment: "Welcome title")
    static let welcomeSubtitle = NSLocalizedString("Explore your files like never before", comment: "Welcome subtitle")
    static let getStarted = NSLocalizedString("Get Started", comment: "Get started button")
    static let skipTour = NSLocalizedString("Skip Tour", comment: "Skip tour button")
    static let nextStep = NSLocalizedString("Next", comment: "Next step button")
    static let previousStep = NSLocalizedString("Previous", comment: "Previous step button")
    
    // MARK: - Accessibility
    static let mapAccessibilityLabel = NSLocalizedString("Interactive file system map", comment: "Map accessibility label")
    static let nodeAccessibilityLabel = NSLocalizedString("File node", comment: "Node accessibility label")
    static let directoryAccessibilityLabel = NSLocalizedString("Directory node", comment: "Directory accessibility label")
    static let zoomControlsAccessibilityLabel = NSLocalizedString("Zoom controls", comment: "Zoom controls accessibility label")
    
    // MARK: - Units
    static let bytes = NSLocalizedString("bytes", comment: "Bytes unit")
    static let kilobytes = NSLocalizedString("KB", comment: "Kilobytes unit")
    static let megabytes = NSLocalizedString("MB", comment: "Megabytes unit")
    static let gigabytes = NSLocalizedString("GB", comment: "Gigabytes unit")
    static let terabytes = NSLocalizedString("TB", comment: "Terabytes unit")
    
    static let fps = NSLocalizedString("FPS", comment: "Frames per second unit")
    static let milliseconds = NSLocalizedString("ms", comment: "Milliseconds unit")
    static let seconds = NSLocalizedString("s", comment: "Seconds unit")
    static let percent = NSLocalizedString("%", comment: "Percent unit")
    
    // MARK: - App Store
    static let appStoreDescription = NSLocalizedString("""
    DataMap Pro transforms your file system into an interactive 3D world map.
    
    ✨ FEATURES:
    • 🌍 3D World Visualization: See your entire file system as a beautiful interactive globe
    • ⚡ Real-time Scanning: Scan thousands of files in seconds with GPU acceleration
    • 🎨 Custom Styling: Color-code files by type, size, or date
    • 🔍 Smart Search: Instantly find files with spatial search
    • 📊 Analytics: Get insights into your storage usage
    • 🖥️ Cross-Platform: Available on iPhone, iPad, and Mac
    
    PERFECT FOR:
    • Developers managing large codebases
    • Photographers organizing thousands of images
    • Students organizing research materials
    • Anyone who wants a visual approach to file management
    
    PRIVACY:
    • 100% local processing
    • No internet access required
    • No data collection
    
    Download now and experience your files like never before!
    """, comment: "App Store description")
    
    // MARK: - Helper Functions
    
    static func formatFileCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
    
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: bytes)
    }
    
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "\(seconds)s"
    }
    
    static func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }
}

// MARK: - Localization Extensions
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Language Support
enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case turkish = "tr"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case chinese = "zh"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .turkish: return "🇹🇷"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        }
    }
}