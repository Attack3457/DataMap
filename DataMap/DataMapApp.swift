// 📁 File: DataMapApp.swift
// 🎯 ENHANCED APP SETUP WITH METAL AND PERFORMANCE MONITORING

import SwiftUI
import SwiftData
import MetalKit

@main
struct DataMapApp: App {
    @StateObject private var performanceMonitor = PerformanceMonitor()
    @StateObject private var enhancedPerformanceMonitor = EnhancedPerformanceMonitor()
    @StateObject private var performanceSettings = PerformanceSettings()
    @StateObject private var viewModel = GraphViewModel()
    
    private let analyticsManager = AnalyticsManager.shared
    
    @State private var showOnboarding = false
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FileNode.self,
            Project.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ SwiftData ModelContainer created successfully")
            return container
        } catch {
            print("❌ SwiftData ModelContainer creation failed: \(error)")
            print("🔄 Falling back to in-memory container...")
            
            // Fallback to in-memory container
            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: false
            )
            
            do {
                let fallbackContainer = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                print("✅ Fallback in-memory container created")
                return fallbackContainer
            } catch {
                print("💥 Critical: Even fallback container failed: \(error)")
                // Son çare olarak minimal container
                fatalError("Could not create any ModelContainer: \(error)")
            }
        }
    }()
    
    init() {
        // Safely setup Metal device with error handling
        setupMetalDevice()
        
        // Check if onboarding should be shown
        showOnboarding = !UserDefaults.standard.bool(forKey: "onboarding_completed")
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView()
                } else {
                    ContentView()
                }
            }
            .environmentObject(viewModel)
            .environmentObject(performanceMonitor)
            .environmentObject(enhancedPerformanceMonitor)
            .environmentObject(performanceSettings)
            .environmentObject(analyticsManager)
            .modelContainer(sharedModelContainer)
            .onAppear {
                // Configure performance settings on first launch
                performanceSettings.detectOptimalSettings()
                performanceSettings.saveToUserDefaults()
                
                // Log app launch
                analyticsManager.logAppLaunched()
                
                // Start performance monitoring
                startPerformanceMonitoring()
            }
            .onDisappear {
                stopPerformanceMonitoring()
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Performance Dashboard") {
                    showPerformanceDashboard()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Button("Analytics Dashboard") {
                    showAnalyticsDashboard()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Quick Start Guide") {
                    showQuickStartGuide()
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(performanceSettings)
                .environmentObject(analyticsManager)
        }
        #endif
    }
    
    private func setupMetalDevice() {
        // Check if Metal is actually needed
        let useMetalRendering = UserDefaults.standard.bool(forKey: "use_metal_rendering")
        
        // Debug flag to completely disable Metal during testing
        #if DEBUG
        let debugDisableMetal = ProcessInfo.processInfo.environment["DISABLE_METAL"] == "1"
        if debugDisableMetal {
            print("🔧 Metal rendering disabled via DEBUG flag")
            UserDefaults.standard.set(false, forKey: "use_metal_rendering")
            return
        }
        #endif
        
        guard useMetalRendering else {
            print("🔧 Metal rendering disabled in settings - skipping Metal setup")
            return
        }
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("⚠️ Metal is not supported on this device")
            return
        }
        
        // Print Metal device info
        print("""
        🔧 Metal Device Info:
        - Name: \(device.name)
        - Supports GPU Family: \(device.supportsFamily(.apple7) ? "Apple 7+" : "Older")
        - Max Threads Per Threadgroup: \(device.maxThreadsPerThreadgroup)
        - Has Unified Memory: \(device.hasUnifiedMemory)
        - Max Buffer Length: \(device.maxBufferLength / 1024 / 1024) MB
        """)
        
        // Test Metal library compilation
        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle.main)
            if library.functionNames.contains("vertex_main") && library.functionNames.contains("fragment_main") {
                print("✅ Metal shaders compiled successfully")
            } else {
                print("⚠️ Metal shader functions not found - disabling Metal rendering")
                UserDefaults.standard.set(false, forKey: "use_metal_rendering")
                return
            }
        } catch {
            print("❌ Metal library compilation failed: \(error)")
            print("🔄 Disabling Metal rendering for this session")
            UserDefaults.standard.set(false, forKey: "use_metal_rendering")
            return
        }
        
        // Log Metal capabilities
        analyticsManager.logEvent("metal_device_detected", properties: [
            "device_name": device.name,
            "supports_apple7": String(device.supportsFamily(.apple7)),
            "has_unified_memory": String(device.hasUnifiedMemory),
            "max_threads": String(device.maxThreadsPerThreadgroup.width)
        ])
    }
    
    private func startPerformanceMonitoring() {
        performanceMonitor.startMonitoring()
        enhancedPerformanceMonitor.startMonitoring()
        
        print("🚀 Performance monitoring started")
    }
    
    private func stopPerformanceMonitoring() {
        performanceMonitor.stopMonitoring()
        enhancedPerformanceMonitor.stopMonitoring()
        
        print("⏹️ Performance monitoring stopped")
    }
    
    private func showPerformanceDashboard() {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Performance Dashboard"
        alert.informativeText = enhancedPerformanceMonitor.getPerformanceSummary()
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Export Data")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            exportPerformanceData()
        }
        #endif
    }
    
    private func showAnalyticsDashboard() {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Analytics Dashboard"
        alert.informativeText = analyticsManager.getDataSummary()
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Export Data")
        alert.addButton(withTitle: "Clear Data")
        
        let response = alert.runModal()
        switch response {
        case .alertSecondButtonReturn:
            exportAnalyticsData()
        case .alertThirdButtonReturn:
            analyticsManager.clearAnalyticsData()
        default:
            break
        }
        #endif
    }
    
    private func showQuickStartGuide() {
        // This would show the quick start guide
        print("📖 Quick Start Guide requested")
    }
    
    private func exportPerformanceData() {
        guard let data = enhancedPerformanceMonitor.exportMetricsAsJSON() else { return }
        
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "performance_metrics_\(Date().ISO8601Format()).json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? data.write(to: url)
            print("📊 Performance data exported to: \(url.path)")
        }
        #endif
    }
    
    private func exportAnalyticsData() {
        guard let data = analyticsManager.exportAnalyticsData() else { return }
        
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "analytics_data_\(Date().ISO8601Format()).json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? data.write(to: url)
            print("📈 Analytics data exported to: \(url.path)")
        }
        #endif
    }
}
