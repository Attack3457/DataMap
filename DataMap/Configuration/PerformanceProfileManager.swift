// 📁 File: Configuration/PerformanceProfileManager.swift
// 🎯 PERFORMANCE PROFILE MANAGEMENT

import Foundation

// MARK: - Performance Profile Manager
actor PerformanceProfileManager {
    private var profiles: [String: PerformanceProfile] = [:]
    private var activeProfile: String = "default"
    
    struct PerformanceProfile: Codable {
        let name: String
        var qualityLevel: PerformanceSettings.QualityLevel
        var targetFrameRate: PerformanceSettings.FrameRate
        var maxVisibleNodes: Int
        var enableGPUAcceleration: Bool
        var enableCaching: Bool
        var cacheSizeMB: Int
        var description: String
        
        static let `default` = PerformanceProfile(
            name: "Default",
            qualityLevel: .balanced,
            targetFrameRate: .sixty,
            maxVisibleNodes: 5000,
            enableGPUAcceleration: true,
            enableCaching: true,
            cacheSizeMB: 256,
            description: "Balanced performance for most devices"
        )
        
        static let powerSaving = PerformanceProfile(
            name: "Power Saving",
            qualityLevel: .powerSaving,
            targetFrameRate: .thirty,
            maxVisibleNodes: 1000,
            enableGPUAcceleration: false,
            enableCaching: true,
            cacheSizeMB: 64,
            description: "Maximizes battery life"
        )
        
        static let highPerformance = PerformanceProfile(
            name: "High Performance",
            qualityLevel: .quality,
            targetFrameRate: .oneTwenty,
            maxVisibleNodes: 10000,
            enableGPUAcceleration: true,
            enableCaching: true,
            cacheSizeMB: 512,
            description: "Maximum performance for capable devices"
        )
        
        static let visualQuality = PerformanceProfile(
            name: "Visual Quality",
            qualityLevel: .ultra,
            targetFrameRate: .sixty,
            maxVisibleNodes: 20000,
            enableGPUAcceleration: true,
            enableCaching: true,
            cacheSizeMB: 1024,
            description: "Prioritizes visual quality over performance"
        )
    }
    
    init() {
        // Load default profiles
        profiles["default"] = .default
        profiles["powerSaving"] = .powerSaving
        profiles["highPerformance"] = .highPerformance
        profiles["visualQuality"] = .visualQuality
        
        // Load custom profiles from storage
        Task {
            await loadCustomProfiles()
        }
    }
    
    func getProfile(named name: String) -> PerformanceProfile? {
        return profiles[name]
    }
    
    func setActiveProfile(_ name: String) {
        if profiles[name] != nil {
            activeProfile = name
        }
    }
    
    func getActiveProfile() -> PerformanceProfile {
        return profiles[activeProfile] ?? .default
    }
    
    func createCustomProfile(
        name: String,
        qualityLevel: PerformanceSettings.QualityLevel,
        targetFrameRate: PerformanceSettings.FrameRate,
        maxVisibleNodes: Int,
        enableGPUAcceleration: Bool,
        enableCaching: Bool,
        cacheSizeMB: Int,
        description: String
    ) {
        let profile = PerformanceProfile(
            name: name,
            qualityLevel: qualityLevel,
            targetFrameRate: targetFrameRate,
            maxVisibleNodes: maxVisibleNodes,
            enableGPUAcceleration: enableGPUAcceleration,
            enableCaching: enableCaching,
            cacheSizeMB: cacheSizeMB,
            description: description
        )
        
        profiles[name] = profile
        saveCustomProfiles()
    }
    
    func deleteProfile(named name: String) {
        guard name != "default" else { return }
        profiles.removeValue(forKey: name)
        saveCustomProfiles()
    }
    
    func getAllProfiles() -> [PerformanceProfile] {
        return Array(profiles.values)
    }
    
    private func loadCustomProfiles() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "customPerformanceProfiles"),
           let customProfiles = try? JSONDecoder().decode([String: PerformanceProfile].self, from: data) {
            for (key, profile) in customProfiles {
                profiles[key] = profile
            }
        }
    }
    
    private func saveCustomProfiles() {
        // Filter out default profiles and save only custom ones
        let customProfiles = profiles.filter { key, _ in
            !["default", "powerSaving", "highPerformance", "visualQuality"].contains(key)
        }
        
        if let data = try? JSONEncoder().encode(customProfiles) {
            UserDefaults.standard.set(data, forKey: "customPerformanceProfiles")
        }
    }
    
    func applyProfile(to settings: PerformanceSettings) async {
        let profile = getActiveProfile()
        
        await MainActor.run {
            settings.qualityLevel = profile.qualityLevel
            settings.targetFrameRate = profile.targetFrameRate
            settings.maxVisibleNodes = profile.maxVisibleNodes
            settings.enableGPUAcceleration = profile.enableGPUAcceleration
            settings.enableCaching = profile.enableCaching
            settings.cacheSizeMB = profile.cacheSizeMB
            settings.applySettings()
        }
    }
}

// MARK: - Codable Extensions
extension PerformanceSettings.QualityLevel: Codable {}
extension PerformanceSettings.FrameRate: Codable {}