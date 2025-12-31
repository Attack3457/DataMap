// 📁 File: Configuration/PerformanceMonitor.swift
// 🎯 REAL-TIME PERFORMANCE MONITORING

import Foundation
import UIKit
import Combine

@MainActor
final class PerformanceMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentMetrics: PerformanceMetrics = PerformanceMetrics(
        frameRate: 60,
        spatialQueryTime: 0,
        cacheHitRate: 0,
        memoryUsage: 0,
        nodeCount: 0,
        quadTreeDepth: 0,
        bvhNodes: 0
    )
    
    @Published var isMonitoring: Bool = false
    @Published var averageFrameRate: Double = 60.0
    @Published var memoryPressure: MemoryPressure = .normal
    
    // MARK: - Private Properties
    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var frameRateHistory: [Double] = []
    private var memoryHistory: [Int] = []
    private var queryTimeHistory: [Double] = []
    private var cacheHitHistory: [Double] = []
    
    private let maxHistorySize = 60 // Keep 60 samples (1 second at 60fps)
    private var updateTimer: Timer?
    
    // MARK: - Memory Pressure
    enum MemoryPressure: String, CaseIterable {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
        
        var color: UIColor {
            switch self {
            case .normal: return .systemGreen
            case .warning: return .systemOrange
            case .critical: return .systemRed
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        setupMemoryPressureMonitoring()
    }
    
    deinit {
        // Note: Cannot call async methods in deinit
        // stopMonitoring() should be called manually before deallocation
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start frame rate monitoring
        startFrameRateMonitoring()
        
        // Start periodic updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        
        print("Performance monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // Stop frame rate monitoring
        displayLink?.invalidate()
        displayLink = nil
        
        // Stop timer
        updateTimer?.invalidate()
        updateTimer = nil
        
        print("Performance monitoring stopped")
    }
    
    func recordSpatialQueryTime(_ time: Double) {
        queryTimeHistory.append(time)
        if queryTimeHistory.count > maxHistorySize {
            queryTimeHistory.removeFirst()
        }
    }
    
    func recordCacheHit(_ isHit: Bool) {
        let hitValue = isHit ? 1.0 : 0.0
        cacheHitHistory.append(hitValue)
        if cacheHitHistory.count > maxHistorySize {
            cacheHitHistory.removeFirst()
        }
    }
    
    func updateNodeCount(_ count: Int) {
        currentMetrics = PerformanceMetrics(
            frameRate: currentMetrics.frameRate,
            spatialQueryTime: currentMetrics.spatialQueryTime,
            cacheHitRate: currentMetrics.cacheHitRate,
            memoryUsage: currentMetrics.memoryUsage,
            nodeCount: count,
            quadTreeDepth: currentMetrics.quadTreeDepth,
            bvhNodes: currentMetrics.bvhNodes
        )
    }
    
    func updateSpatialStructure(quadTreeDepth: Int, bvhNodes: Int) {
        currentMetrics = PerformanceMetrics(
            frameRate: currentMetrics.frameRate,
            spatialQueryTime: currentMetrics.spatialQueryTime,
            cacheHitRate: currentMetrics.cacheHitRate,
            memoryUsage: currentMetrics.memoryUsage,
            nodeCount: currentMetrics.nodeCount,
            quadTreeDepth: quadTreeDepth,
            bvhNodes: bvhNodes
        )
    }
    
    // MARK: - Statistics
    
    func getFrameRateStatistics() -> (min: Double, max: Double, average: Double) {
        guard !frameRateHistory.isEmpty else { return (0, 0, 0) }
        
        let min = frameRateHistory.min() ?? 0
        let max = frameRateHistory.max() ?? 0
        let average = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        
        return (min, max, average)
    }
    
    func getMemoryStatistics() -> (current: Int, peak: Int, average: Int) {
        guard !memoryHistory.isEmpty else { return (0, 0, 0) }
        
        let current = getCurrentMemoryUsage()
        let peak = memoryHistory.max() ?? 0
        let average = memoryHistory.reduce(0, +) / memoryHistory.count
        
        return (current, peak, average)
    }
    
    func getQueryTimeStatistics() -> (min: Double, max: Double, average: Double) {
        guard !queryTimeHistory.isEmpty else { return (0, 0, 0) }
        
        let min = queryTimeHistory.min() ?? 0
        let max = queryTimeHistory.max() ?? 0
        let average = queryTimeHistory.reduce(0, +) / Double(queryTimeHistory.count)
        
        return (min, max, average)
    }
    
    func getCacheHitRate() -> Double {
        guard !cacheHitHistory.isEmpty else { return 0 }
        
        let hits = cacheHitHistory.reduce(0, +)
        return hits / Double(cacheHitHistory.count)
    }
    
    // MARK: - Private Methods
    
    private func startFrameRateMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.add(to: .main, forMode: .common)
        lastFrameTime = CACurrentMediaTime()
    }
    
    @objc private func displayLinkCallback() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        
        if deltaTime > 0 {
            let frameRate = 1.0 / deltaTime
            frameRateHistory.append(frameRate)
            
            if frameRateHistory.count > maxHistorySize {
                frameRateHistory.removeFirst()
            }
            
            // Update average
            averageFrameRate = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        }
        
        lastFrameTime = currentTime
        frameCount += 1
    }
    
    private func updateMetrics() {
        let memoryUsage = getCurrentMemoryUsage()
        memoryHistory.append(memoryUsage)
        
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst()
        }
        
        // Update memory pressure
        updateMemoryPressure(memoryUsage)
        
        // Calculate averages
        let avgQueryTime = queryTimeHistory.isEmpty ? 0 : queryTimeHistory.reduce(0, +) / Double(queryTimeHistory.count)
        let cacheHitRate = getCacheHitRate()
        
        // Update current metrics
        currentMetrics = PerformanceMetrics(
            frameRate: averageFrameRate,
            spatialQueryTime: avgQueryTime,
            cacheHitRate: cacheHitRate,
            memoryUsage: memoryUsage,
            nodeCount: currentMetrics.nodeCount,
            quadTreeDepth: currentMetrics.quadTreeDepth,
            bvhNodes: currentMetrics.bvhNodes
        )
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size / 1024 / 1024) // Convert to MB
        } else {
            return 0
        }
    }
    
    private func updateMemoryPressure(_ memoryUsage: Int) {
        // Simple heuristic for memory pressure
        if memoryUsage > 500 { // 500MB
            memoryPressure = .critical
        } else if memoryUsage > 300 { // 300MB
            memoryPressure = .warning
        } else {
            memoryPressure = .normal
        }
    }
    
    private func setupMemoryPressureMonitoring() {
        // Monitor system memory pressure notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.memoryPressure = .critical
            print("System memory warning received")
        }
    }
    
    // MARK: - Export Methods
    
    func exportMetricsAsJSON() -> Data? {
        let exportData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "currentMetrics": [
                "frameRate": currentMetrics.frameRate,
                "spatialQueryTime": currentMetrics.spatialQueryTime,
                "cacheHitRate": currentMetrics.cacheHitRate,
                "memoryUsage": currentMetrics.memoryUsage,
                "nodeCount": currentMetrics.nodeCount,
                "quadTreeDepth": currentMetrics.quadTreeDepth,
                "bvhNodes": currentMetrics.bvhNodes
            ],
            "statistics": [
                "frameRate": getFrameRateStatistics(),
                "memory": getMemoryStatistics(),
                "queryTime": getQueryTimeStatistics(),
                "cacheHitRate": getCacheHitRate()
            ],
            "history": [
                "frameRates": frameRateHistory,
                "memoryUsage": memoryHistory,
                "queryTimes": queryTimeHistory,
                "cacheHits": cacheHitHistory
            ]
        ]
        
        do {
            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        } catch {
            print("Failed to export metrics: \(error)")
            return nil
        }
    }
    
    func resetHistory() {
        frameRateHistory.removeAll()
        memoryHistory.removeAll()
        queryTimeHistory.removeAll()
        cacheHitHistory.removeAll()
        frameCount = 0
        averageFrameRate = 60.0
    }
}

// MARK: - Preview Support
extension PerformanceMonitor {
    static var previewMonitor: PerformanceMonitor {
        let monitor = PerformanceMonitor()
        monitor.currentMetrics = PerformanceMetrics(
            frameRate: 58.5,
            spatialQueryTime: 12.3,
            cacheHitRate: 0.85,
            memoryUsage: 180,
            nodeCount: 7500,
            quadTreeDepth: 6,
            bvhNodes: 1250
        )
        monitor.averageFrameRate = 58.5
        monitor.memoryPressure = .normal
        return monitor
    }
}