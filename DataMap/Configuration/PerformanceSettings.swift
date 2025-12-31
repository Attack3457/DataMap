// 📁 File: Configuration/PerformanceSettings.swift
// 🎯 PERFORMANCE CONFIGURATION AND ADAPTIVE OPTIMIZATION

import Foundation
import UIKit
import Metal
import Combine

// MARK: - Performance Metrics Structure
struct PerformanceMetrics {
    let frameRate: Double
    let spatialQueryTime: Double // milliseconds
    let cacheHitRate: Double // 0.0 to 1.0
    let memoryUsage: Int // MB
    let nodeCount: Int
    let quadTreeDepth: Int
    let bvhNodes: Int
}

@MainActor
final class PerformanceSettings: ObservableObject {
    
    // MARK: - Published Properties
    @Published var qualityLevel: QualityLevel = .balanced
    @Published var targetFrameRate: FrameRate = .sixty
    @Published var enableGPUAcceleration: Bool = true
    @Published var enableCaching: Bool = true
    @Published var maxVisibleNodes: Int = 5000
    @Published var cacheSizeMB: Int = 256
    
    // MARK: - Adaptive Settings
    private var currentDeviceTier: DeviceTier = .detect()
    private var lastOptimizationTime: Date = Date()
    private var optimizationCooldown: TimeInterval = 5.0 // seconds
    
    // MARK: - Quality Levels
    enum QualityLevel: Int, CaseIterable, Identifiable {
        case powerSaving = 0
        case balanced = 1
        case quality = 2
        case ultra = 3
        
        var id: Int { rawValue }
        
        var name: String {
            switch self {
            case .powerSaving: return "Power Saving"
            case .balanced: return "Balanced"
            case .quality: return "Quality"
            case .ultra: return "Ultra"
            }
        }
        
        var description: String {
            switch self {
            case .powerSaving:
                return "Maximizes battery life, reduces visual quality"
            case .balanced:
                return "Balances performance and visual quality"
            case .quality:
                return "Prioritizes visual quality, may use more power"
            case .ultra:
                return "Maximum visual quality, for high-end devices"
            }
        }
        
        var settings: QualitySettings {
            switch self {
            case .powerSaving:
                return QualitySettings(
                    maxVisibleNodes: 1000,
                    lodBias: 2,
                    enableShadows: false,
                    enableReflections: false,
                    textureQuality: .low,
                    antialiasing: .none,
                    shadowQuality: .low,
                    reflectionQuality: .low,
                    particleQuality: .low,
                    enablePostProcessing: false
                )
            case .balanced:
                return QualitySettings(
                    maxVisibleNodes: 5000,
                    lodBias: 1,
                    enableShadows: true,
                    enableReflections: false,
                    textureQuality: .medium,
                    antialiasing: .fxaa,
                    shadowQuality: .medium,
                    reflectionQuality: .low,
                    particleQuality: .medium,
                    enablePostProcessing: true
                )
            case .quality:
                return QualitySettings(
                    maxVisibleNodes: 10000,
                    lodBias: 0,
                    enableShadows: true,
                    enableReflections: true,
                    textureQuality: .high,
                    antialiasing: .msaa2x,
                    shadowQuality: .high,
                    reflectionQuality: .medium,
                    particleQuality: .high,
                    enablePostProcessing: true
                )
            case .ultra:
                return QualitySettings(
                    maxVisibleNodes: 20000,
                    lodBias: -1,
                    enableShadows: true,
                    enableReflections: true,
                    textureQuality: .ultra,
                    antialiasing: .msaa4x,
                    shadowQuality: .ultra,
                    reflectionQuality: .high,
                    particleQuality: .ultra,
                    enablePostProcessing: true
                )
            }
        }
    }
    
    // MARK: - Frame Rate
    enum FrameRate: Int, CaseIterable, Identifiable {
        case thirty = 30
        case sixty = 60
        case oneTwenty = 120
        case adaptive = 0
        
        var id: Int { rawValue }
        
        var name: String {
            switch self {
            case .thirty: return "30 FPS"
            case .sixty: return "60 FPS"
            case .oneTwenty: return "120 FPS"
            case .adaptive: return "Adaptive"
            }
        }
        
        var frameTime: TimeInterval {
            switch self {
            case .thirty: return 1.0 / 30.0
            case .sixty: return 1.0 / 60.0
            case .oneTwenty: return 1.0 / 120.0
            case .adaptive: return 1.0 / 60.0 // Default
            }
        }
    }
    
    // MARK: - Device Tier
    enum DeviceTier: Int {
        case low = 0      // Old devices, limited RAM
        case medium = 1   // Average devices
        case high = 2     // Recent devices
        case ultra = 3    // Latest flagship devices
        
        static func detect() -> DeviceTier {
            let processInfo = ProcessInfo.processInfo
            
            // Check RAM
            let physicalMemory = processInfo.physicalMemory
            let ramGB = Double(physicalMemory) / 1_000_000_000
            
            // Check CPU cores
            let coreCount = processInfo.processorCount
            
            // Check GPU capabilities (simplified)
            let hasPowerfulGPU = MTLCreateSystemDefaultDevice()?.supportsFamily(.apple3) ?? false
            
            if ramGB < 2 || coreCount < 2 {
                return .low
            } else if ramGB < 4 || coreCount < 4 {
                return .medium
            } else if ramGB >= 6 && coreCount >= 6 && hasPowerfulGPU {
                return .ultra
            } else {
                return .high
            }
        }
        
        var recommendedQuality: QualityLevel {
            switch self {
            case .low: return .powerSaving
            case .medium: return .balanced
            case .high: return .quality
            case .ultra: return .ultra
            }
        }
        
        var maxRecommendedNodes: Int {
            switch self {
            case .low: return 2000
            case .medium: return 5000
            case .high: return 10000
            case .ultra: return 20000
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        detectOptimalSettings()
        startAdaptiveOptimization()
    }
    
    // MARK: - Public Methods
    
    func detectOptimalSettings() {
        let tier = DeviceTier.detect()
        currentDeviceTier = tier
        
        // Apply device-appropriate settings
        qualityLevel = tier.recommendedQuality
        maxVisibleNodes = tier.maxRecommendedNodes
        
        print("Detected device tier: \(tier)")
        print("Applied settings: \(qualityLevel.name)")
    }
    
    func applySettings() {
        // Apply quality settings to the renderer
        let settings = qualityLevel.settings
        
        // Update renderer settings
        updateRendererSettings(settings)
        
        // Update cache size based on quality
        updateCacheSize()
        
        print("Applied quality settings: \(qualityLevel.name)")
    }
    
    func optimizeForPerformance(metrics: PerformanceMetrics) {
        let now = Date()
        
        // Apply cooldown to prevent rapid adjustments
        guard now.timeIntervalSince(lastOptimizationTime) > optimizationCooldown else {
            return
        }
        lastOptimizationTime = now
        
        // Check frame rate
        if metrics.frameRate < 45 {
            // Frame rate too low, reduce quality
            reduceQualityLevel()
        } else if metrics.frameRate > 75 && qualityLevel != .ultra {
            // Frame rate good, consider increasing quality
            increaseQualityLevelIfPossible()
        }
        
        // Check memory usage
        if metrics.memoryUsage > 300 { // 300MB
            reduceMemoryUsage()
        }
        
        applySettings()
    }
    
    func saveToUserDefaults() {
        UserDefaults.standard.set(qualityLevel.rawValue, forKey: "qualityLevel")
        UserDefaults.standard.set(targetFrameRate.rawValue, forKey: "targetFrameRate")
        UserDefaults.standard.set(enableGPUAcceleration, forKey: "enableGPUAcceleration")
        UserDefaults.standard.set(enableCaching, forKey: "enableCaching")
        UserDefaults.standard.set(maxVisibleNodes, forKey: "maxVisibleNodes")
        UserDefaults.standard.set(cacheSizeMB, forKey: "cacheSizeMB")
    }
    
    func loadFromUserDefaults() {
        if let rawValue = UserDefaults.standard.value(forKey: "qualityLevel") as? Int,
           let level = QualityLevel(rawValue: rawValue) {
            qualityLevel = level
        }
        
        if let rawValue = UserDefaults.standard.value(forKey: "targetFrameRate") as? Int,
           let frameRate = FrameRate(rawValue: rawValue) {
            targetFrameRate = frameRate
        }
        
        enableGPUAcceleration = UserDefaults.standard.bool(forKey: "enableGPUAcceleration")
        enableCaching = UserDefaults.standard.bool(forKey: "enableCaching")
        maxVisibleNodes = UserDefaults.standard.integer(forKey: "maxVisibleNodes")
        cacheSizeMB = UserDefaults.standard.integer(forKey: "cacheSizeMB")
    }
    
    // MARK: - Private Methods
    
    private func startAdaptiveOptimization() {
        // Monitor performance every 10 seconds
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Get current performance metrics from monitor
                // This would come from PerformanceMonitor
                // For now, we'll simulate
                let simulatedMetrics = PerformanceMetrics(
                    frameRate: 60,
                    spatialQueryTime: 10,
                    cacheHitRate: 0.8,
                    memoryUsage: 150,
                    nodeCount: 5000,
                    quadTreeDepth: 8,
                    bvhNodes: 1000
                )
                
                self?.optimizeForPerformance(metrics: simulatedMetrics)
            }
        }
    }
    
    private func reduceQualityLevel() {
        if qualityLevel.rawValue > QualityLevel.powerSaving.rawValue {
            qualityLevel = QualityLevel(rawValue: qualityLevel.rawValue - 1) ?? .powerSaving
            print("Reduced quality level to: \(qualityLevel.name)")
        }
    }
    
    private func increaseQualityLevelIfPossible() {
        // Only increase if we're not already at ultra and device can handle it
        if qualityLevel.rawValue < QualityLevel.ultra.rawValue &&
           qualityLevel.rawValue < currentDeviceTier.recommendedQuality.rawValue {
            qualityLevel = QualityLevel(rawValue: qualityLevel.rawValue + 1) ?? .ultra
            print("Increased quality level to: \(qualityLevel.name)")
        }
    }
    
    private func reduceMemoryUsage() {
        // Reduce cache size
        cacheSizeMB = max(64, cacheSizeMB / 2)
        
        // Reduce max visible nodes
        maxVisibleNodes = max(1000, maxVisibleNodes / 2)
        
        print("Reduced memory usage: Cache=\(cacheSizeMB)MB, MaxNodes=\(maxVisibleNodes)")
    }
    
    private func updateRendererSettings(_ settings: QualitySettings) {
        // This would communicate with the Metal renderer
        // For now, we'll update local properties
        maxVisibleNodes = settings.maxVisibleNodes
        
        // In a real implementation, you would:
        // 1. Update Metal render pipeline states
        // 2. Adjust LOD bias
        // 3. Enable/disable features
        // 4. Change texture quality
    }
    
    private func updateCacheSize() {
        // Adjust cache size based on quality level
        switch qualityLevel {
        case .powerSaving:
            cacheSizeMB = 64
        case .balanced:
            cacheSizeMB = 128
        case .quality:
            cacheSizeMB = 256
        case .ultra:
            cacheSizeMB = 512
        }
    }
}

// MARK: - Quality Settings Structure
struct QualitySettings {
    let maxVisibleNodes: Int
    let lodBias: Int // Positive = lower detail, Negative = higher detail
    let enableShadows: Bool
    let enableReflections: Bool
    let textureQuality: TextureQuality
    let antialiasing: Antialiasing
    let shadowQuality: ShadowQuality
    let reflectionQuality: ReflectionQuality
    let particleQuality: ParticleQuality
    let enablePostProcessing: Bool
}

enum TextureQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"
}

enum Antialiasing: String, CaseIterable {
    case none = "None"
    case fxaa = "FXAA"
    case msaa2x = "MSAA 2x"
    case msaa4x = "MSAA 4x"
    case msaa8x = "MSAA 8x"
}

enum ShadowQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"
}

enum ReflectionQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum ParticleQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"
}