// 📁 File: Views/PerformanceSettingsView.swift
// 🎯 PERFORMANCE SETTINGS USER INTERFACE

import SwiftUI
import Charts

struct PerformanceSettingsView: View {
    @StateObject private var performanceSettings = PerformanceSettings()
    @StateObject private var performanceMonitor = PerformanceMonitor()
    @State private var profileManager = PerformanceProfileManager()
    @State private var availableProfiles: [PerformanceProfileManager.PerformanceProfile] = []
    @State private var selectedProfile: String = "default"
    @State private var showingCreateProfile = false
    
    var body: some View {
        NavigationView {
            Form {
                // Current Performance Section
                Section("Current Performance") {
                    PerformanceMetricsView(monitor: performanceMonitor)
                }
                
                // Quality Settings Section
                Section("Quality Settings") {
                    QualitySettingsView(settings: performanceSettings)
                }
                
                // Performance Profiles Section
                Section("Performance Profiles") {
                    ProfileSelectionView(
                        profiles: availableProfiles,
                        selectedProfile: $selectedProfile,
                        onProfileChange: applyProfile
                    )
                    
                    Button("Create Custom Profile") {
                        showingCreateProfile = true
                    }
                    .foregroundColor(.blue)
                }
                
                // Advanced Settings Section
                Section("Advanced Settings") {
                    AdvancedSettingsView(settings: performanceSettings)
                }
                
                // Actions Section
                Section("Actions") {
                    Button("Reset to Optimal") {
                        performanceSettings.detectOptimalSettings()
                    }
                    
                    Button("Export Performance Data") {
                        exportPerformanceData()
                    }
                    
                    Button(performanceMonitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                        if performanceMonitor.isMonitoring {
                            performanceMonitor.stopMonitoring()
                        } else {
                            performanceMonitor.startMonitoring()
                        }
                    }
                    .foregroundColor(performanceMonitor.isMonitoring ? .red : .green)
                }
            }
            .navigationTitle("Performance Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadProfiles()
                performanceSettings.loadFromUserDefaults()
                performanceMonitor.startMonitoring()
            }
            .onDisappear {
                performanceSettings.saveToUserDefaults()
            }
            .sheet(isPresented: $showingCreateProfile) {
                CreateProfileView(
                    profileManager: profileManager,
                    currentSettings: performanceSettings,
                    onProfileCreated: loadProfiles
                )
            }
        }
    }
    
    private func loadProfiles() {
        Task {
            availableProfiles = await profileManager.getAllProfiles()
            selectedProfile = await profileManager.getActiveProfile().name
        }
    }
    
    private func applyProfile(_ profileName: String) {
        Task {
            await profileManager.setActiveProfile(profileName)
            await profileManager.applyProfile(to: performanceSettings)
            selectedProfile = profileName
        }
    }
    
    private func exportPerformanceData() {
        guard let data = performanceMonitor.exportMetricsAsJSON() else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [data],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Performance Metrics View
struct PerformanceMetricsView: View {
    @ObservedObject var monitor: PerformanceMonitor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Frame Rate
            HStack {
                Label("Frame Rate", systemImage: "speedometer")
                Spacer()
                Text("\(monitor.currentMetrics.frameRate, specifier: "%.1f") FPS")
                    .foregroundColor(frameRateColor)
            }
            
            // Memory Usage
            HStack {
                Label("Memory Usage", systemImage: "memorychip")
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(monitor.currentMetrics.memoryUsage) MB")
                    Text(monitor.memoryPressure.rawValue)
                        .font(.caption)
                        .foregroundColor(Color(monitor.memoryPressure.color))
                }
            }
            
            // Cache Hit Rate
            HStack {
                Label("Cache Hit Rate", systemImage: "externaldrive.connected.to.line.below")
                Spacer()
                Text("\(monitor.currentMetrics.cacheHitRate * 100, specifier: "%.1f")%")
                    .foregroundColor(cacheHitColor)
            }
            
            // Node Count
            HStack {
                Label("Visible Nodes", systemImage: "point.3.connected.trianglepath.dotted")
                Spacer()
                Text("\(monitor.currentMetrics.nodeCount)")
            }
            
            // Query Time
            HStack {
                Label("Query Time", systemImage: "clock")
                Spacer()
                Text("\(monitor.currentMetrics.spatialQueryTime, specifier: "%.1f") ms")
                    .foregroundColor(queryTimeColor)
            }
        }
    }
    
    private var frameRateColor: Color {
        if monitor.currentMetrics.frameRate >= 55 {
            return .green
        } else if monitor.currentMetrics.frameRate >= 30 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var cacheHitColor: Color {
        if monitor.currentMetrics.cacheHitRate >= 0.8 {
            return .green
        } else if monitor.currentMetrics.cacheHitRate >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var queryTimeColor: Color {
        if monitor.currentMetrics.spatialQueryTime <= 10 {
            return .green
        } else if monitor.currentMetrics.spatialQueryTime <= 20 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Quality Settings View
struct QualitySettingsView: View {
    @ObservedObject var settings: PerformanceSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quality Level
            VStack(alignment: .leading) {
                Text("Quality Level")
                    .font(.headline)
                Picker("Quality Level", selection: $settings.qualityLevel) {
                    ForEach(PerformanceSettings.QualityLevel.allCases) { level in
                        VStack(alignment: .leading) {
                            Text(level.name)
                            Text(level.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Target Frame Rate
            VStack(alignment: .leading) {
                Text("Target Frame Rate")
                    .font(.headline)
                Picker("Frame Rate", selection: $settings.targetFrameRate) {
                    ForEach(PerformanceSettings.FrameRate.allCases) { rate in
                        Text(rate.name).tag(rate)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Max Visible Nodes
            VStack(alignment: .leading) {
                Text("Max Visible Nodes: \(settings.maxVisibleNodes)")
                    .font(.headline)
                Slider(
                    value: Binding(
                        get: { Double(settings.maxVisibleNodes) },
                        set: { settings.maxVisibleNodes = Int($0) }
                    ),
                    in: 1000...20000,
                    step: 1000
                )
            }
        }
    }
}

// MARK: - Profile Selection View
struct ProfileSelectionView: View {
    let profiles: [PerformanceProfileManager.PerformanceProfile]
    @Binding var selectedProfile: String
    let onProfileChange: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Profile")
                .font(.headline)
            
            Picker("Profile", selection: $selectedProfile) {
                ForEach(profiles, id: \.name) { profile in
                    VStack(alignment: .leading) {
                        Text(profile.name)
                        Text(profile.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(profile.name)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedProfile) { _, newValue in
                onProfileChange(newValue)
            }
        }
    }
}

// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
    @ObservedObject var settings: PerformanceSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("GPU Acceleration", isOn: $settings.enableGPUAcceleration)
            Toggle("Enable Caching", isOn: $settings.enableCaching)
            
            VStack(alignment: .leading) {
                Text("Cache Size: \(settings.cacheSizeMB) MB")
                    .font(.headline)
                Slider(
                    value: Binding(
                        get: { Double(settings.cacheSizeMB) },
                        set: { settings.cacheSizeMB = Int($0) }
                    ),
                    in: 64...1024,
                    step: 64
                )
            }
        }
    }
}

// MARK: - Create Profile View
struct CreateProfileView: View {
    let profileManager: PerformanceProfileManager
    @ObservedObject var currentSettings: PerformanceSettings
    let onProfileCreated: () -> Void
    
    @State private var profileName = ""
    @State private var profileDescription = ""
    @State private var qualityLevel: PerformanceSettings.QualityLevel = .balanced
    @State private var targetFrameRate: PerformanceSettings.FrameRate = .sixty
    @State private var maxVisibleNodes = 5000
    @State private var enableGPUAcceleration = true
    @State private var enableCaching = true
    @State private var cacheSizeMB = 256
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    TextField("Profile Name", text: $profileName)
                    TextField("Description", text: $profileDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    Picker("Quality Level", selection: $qualityLevel) {
                        ForEach(PerformanceSettings.QualityLevel.allCases) { level in
                            Text(level.name).tag(level)
                        }
                    }
                    
                    Picker("Target Frame Rate", selection: $targetFrameRate) {
                        ForEach(PerformanceSettings.FrameRate.allCases) { rate in
                            Text(rate.name).tag(rate)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Max Visible Nodes: \(maxVisibleNodes)")
                        Slider(
                            value: Binding(
                                get: { Double(maxVisibleNodes) },
                                set: { maxVisibleNodes = Int($0) }
                            ),
                            in: 1000...20000,
                            step: 1000
                        )
                    }
                    
                    Toggle("GPU Acceleration", isOn: $enableGPUAcceleration)
                    Toggle("Enable Caching", isOn: $enableCaching)
                    
                    VStack(alignment: .leading) {
                        Text("Cache Size: \(cacheSizeMB) MB")
                        Slider(
                            value: Binding(
                                get: { Double(cacheSizeMB) },
                                set: { cacheSizeMB = Int($0) }
                            ),
                            in: 64...1024,
                            step: 64
                        )
                    }
                }
                
                Section {
                    Button("Use Current Settings") {
                        copyCurrentSettings()
                    }
                }
            }
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProfile()
                    }
                    .disabled(profileName.isEmpty)
                }
            }
        }
    }
    
    private func copyCurrentSettings() {
        qualityLevel = currentSettings.qualityLevel
        targetFrameRate = currentSettings.targetFrameRate
        maxVisibleNodes = currentSettings.maxVisibleNodes
        enableGPUAcceleration = currentSettings.enableGPUAcceleration
        enableCaching = currentSettings.enableCaching
        cacheSizeMB = currentSettings.cacheSizeMB
    }
    
    private func createProfile() {
        Task {
            await profileManager.createCustomProfile(
                name: profileName,
                qualityLevel: qualityLevel,
                targetFrameRate: targetFrameRate,
                maxVisibleNodes: maxVisibleNodes,
                enableGPUAcceleration: enableGPUAcceleration,
                enableCaching: enableCaching,
                cacheSizeMB: cacheSizeMB,
                description: profileDescription
            )
            
            await MainActor.run {
                onProfileCreated()
                dismiss()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PerformanceSettingsView()
}