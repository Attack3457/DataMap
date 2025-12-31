// 📁 File: Configuration/EnhancedPerformanceMonitor.swift
// 🎯 REAL-TIME PERFORMANCE MONITORING AND OPTIMIZATION

import Foundation
import UIKit
import Combine

// MARK: - Enhanced Performance Metrics
struct EnhancedPerformanceMetrics: Codable, Sendable {
    let frameRate: Double
    let spatialQueryTime: Double // milliseconds
    let cacheHitRate: Double // 0.0 to 1.0
    let memoryUsage: Int // MB
    let nodeCount: Int
    let quadTreeDepth: Int
    let bvhNodes: Int
    let cpuUsage: Double // 0.0 to 100.0
    let renderTime: Double // milliseconds
    let timestamp: Date
    let thermalState: String
    let batteryLevel: Double
    
    static let zero = EnhancedPerformanceMetrics(
        frameRate: 0,
        spatialQueryTime: 0,
        cacheHitRate: 0,
        memoryUsage: 0,
        nodeCount: 0,
        quadTreeDepth: 0,
        bvhNodes: 0,
        cpuUsage: 0,
        renderTime: 0,
        timestamp: Date(),
        thermalState: "nominal",
        batteryLevel: 1.0
    )
}

@MainActor
final class EnhancedPerformanceMonitor: ObservableObject {
    
    // MARK: - Types
    enum MemoryPressure: String, CaseIterable, Codable {
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
    
    enum ThermalState: String, CaseIterable {
        case nominal = "Nominal"
        case fair = "Fair"
        case serious = "Serious"
        case critical = "Critical"
        
        var color: UIColor {
            switch self {
            case .nominal: return .systemGreen
            case .fair: return .systemYellow
            case .serious: return .systemOrange
            case .critical: return .systemRed
            }
        }
    }
    
    // MARK: - Published Properties
    @Published private(set) var currentMetrics = EnhancedPerformanceMetrics.zero
    @Published private(set) var memoryPressure: MemoryPressure = .normal
    @Published private(set) var thermalState: ThermalState = .nominal
    @Published private(set) var isMonitoring = false
    @Published private(set) var performanceHistory: [EnhancedPerformanceMetrics] = []
    @Published private(set) var adaptiveQualityEnabled = true
    
    // MARK: - Private Properties
    private var monitorTimer: Timer?
    private var displayLink: CADisplayLink?
    private var lastUpdateTime = Date()
    private var frameCount = 0
    private var cacheHits = 0
    private var cacheMisses = 0
    private let maxHistorySize = 1000
    private var lastFrameTime: CFTimeInterval = 0
    private var frameRateHistory: [Double] = []
    private var memoryHistory: [Int] = []
    private var queryTimeHistory: [Double] = []
    private var cacheHitHistory: [Double] = []
    private var renderTimeHistory: [Double] = []
    private var cpuUsageHistory: [Double] = []
    
    // Performance thresholds
    private let lowFrameRateThreshold: Double = 45.0
    private let highMemoryThreshold: Int = 400 // MB
    private let highCPUThreshold: Double = 80.0
    
    // MARK: - Initialization
    init() {
        setupMemoryPressureMonitoring()
        setupThermalStateMonitoring()
    }
    
    deinit {
        // Note: Cannot call async methods in deinit
        // stopMonitoring() should be called manually before deallocation
    }
    
    // MARK: - Public API
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        performanceHistory.removeAll()
        
        // Start frame rate monitoring
        startFrameRateMonitoring()
        
        // Start periodic updates
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        
        print("Enhanced performance monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // Stop frame rate monitoring
        displayLink?.invalidate()
        displayLink = nil
        
        // Stop timer
        monitorTimer?.invalidate()
        monitorTimer = nil
        
        print("Enhanced performance monitoring stopped")
    }
    
    func recordSpatialQuery(time: Double) {
        queryTimeHistory.append(time)
        if queryTimeHistory.count > maxHistorySize {
            queryTimeHistory.removeFirst()
        }
    }
    
    func recordCacheHit(_ isHit: Bool) {
        if isHit {
            cacheHits += 1
        } else {
            cacheMisses += 1
        }
        
        let hitValue = isHit ? 1.0 : 0.0
        cacheHitHistory.append(hitValue)
        if cacheHitHistory.count > maxHistorySize {
            cacheHitHistory.removeFirst()
        }
    }
    
    func recordRender(time: Double) {
        renderTimeHistory.append(time)
        if renderTimeHistory.count > maxHistorySize {
            renderTimeHistory.removeFirst()
        }
    }
    
    func updateNodeCount(_ count: Int) {
        // This will be updated in the next metrics update cycle
    }
    
    func updateSpatialStructure(quadTreeDepth: Int, bvhNodes: Int) {
        // This will be updated in the next metrics update cycle
    }
    
    func frameRendered() {
        frameCount += 1
        let now = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let deltaTime = now - lastFrameTime
            if deltaTime > 0 {
                let frameRate = 1.0 / deltaTime
                frameRateHistory.append(frameRate)
                
                if frameRateHistory.count > maxHistorySize {
                    frameRateHistory.removeFirst()
                }
            }
        }
        
        lastFrameTime = now
    }
    
    // MARK: - Adaptive Quality Management
    
    func shouldReduceQuality() -> Bool {
        guard adaptiveQualityEnabled else { return false }
        
        let avgFrameRate = frameRateHistory.isEmpty ? 60.0 : frameRateHistory.suffix(10).reduce(0, +) / Double(min(10, frameRateHistory.count))
        let currentMemory = getCurrentMemoryUsage()
        let currentCPU = getCurrentCPUUsage()
        
        return avgFrameRate < lowFrameRateThreshold ||
               currentMemory > highMemoryThreshold ||
               currentCPU > highCPUThreshold ||
               thermalState == .serious ||
               thermalState == .critical
    }
    
    func shouldIncreaseQuality() -> Bool {
        guard adaptiveQualityEnabled else { return false }
        
        let avgFrameRate = frameRateHistory.isEmpty ? 60.0 : frameRateHistory.suffix(10).reduce(0, +) / Double(min(10, frameRateHistory.count))
        let currentMemory = getCurrentMemoryUsage()
        let currentCPU = getCurrentCPUUsage()
        
        return avgFrameRate > 55.0 &&
               currentMemory < 200 &&
               currentCPU < 50.0 &&
               thermalState == .nominal &&
               memoryPressure == .normal
    }
    
    func getQualityRecommendation() -> String {
        if shouldReduceQuality() {
            return "Reduce quality for better performance"
        } else if shouldIncreaseQuality() {
            return "Can increase quality"
        } else {
            return "Current quality is optimal"
        }
    }
    
    // MARK: - Statistics
    
    func getFrameRateStatistics() -> (min: Double, max: Double, average: Double, recent: Double) {
        guard !frameRateHistory.isEmpty else { return (0, 0, 0, 0) }
        
        let minRate = frameRateHistory.min() ?? 0
        let maxRate = frameRateHistory.max() ?? 0
        let average = frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        let recent = frameRateHistory.suffix(10).reduce(0, +) / Double(min(10, frameRateHistory.count))
        
        return (minRate, maxRate, average, recent)
    }
    
    func getMemoryStatistics() -> (current: Int, peak: Int, average: Int) {
        guard !memoryHistory.isEmpty else { return (0, 0, 0) }
        
        let current = getCurrentMemoryUsage()
        let peak = memoryHistory.max() ?? 0
        let average = memoryHistory.reduce(0, +) / memoryHistory.count
        
        return (current, peak, average)
    }
    
    func getCPUStatistics() -> (current: Double, peak: Double, average: Double) {
        guard !cpuUsageHistory.isEmpty else { return (0, 0, 0) }
        
        let current = getCurrentCPUUsage()
        let peak = cpuUsageHistory.max() ?? 0
        let average = cpuUsageHistory.reduce(0, +) / Double(cpuUsageHistory.count)
        
        return (current, peak, average)
    }
    
    func getQueryTimeStatistics() -> (min: Double, max: Double, average: Double) {
        guard !queryTimeHistory.isEmpty else { return (0, 0, 0) }
        
        let min = queryTimeHistory.min() ?? 0
        let max = queryTimeHistory.max() ?? 0
        let average = queryTimeHistory.reduce(0, +) / Double(queryTimeHistory.count)
        
        return (min, max, average)
    }
    
    func getRenderTimeStatistics() -> (min: Double, max: Double, average: Double) {
        guard !renderTimeHistory.isEmpty else { return (0, 0, 0) }
        
        let min = renderTimeHistory.min() ?? 0
        let max = renderTimeHistory.max() ?? 0
        let average = renderTimeHistory.reduce(0, +) / Double(renderTimeHistory.count)
        
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
        frameRendered()
    }
    
    private func updateMetrics() {
        let memoryUsage = getCurrentMemoryUsage()
        let cpuUsage = getCurrentCPUUsage()
        
        memoryHistory.append(memoryUsage)
        cpuUsageHistory.append(cpuUsage)
        
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst()
        }
        
        if cpuUsageHistory.count > maxHistorySize {
            cpuUsageHistory.removeFirst()
        }
        
        // Update memory pressure
        updateMemoryPressure(memoryUsage)
        
        // Calculate averages
        let avgFrameRate = frameRateHistory.isEmpty ? 0 : frameRateHistory.reduce(0, +) / Double(frameRateHistory.count)
        let avgQueryTime = queryTimeHistory.isEmpty ? 0 : queryTimeHistory.reduce(0, +) / Double(queryTimeHistory.count)
        let avgRenderTime = renderTimeHistory.isEmpty ? 0 : renderTimeHistory.reduce(0, +) / Double(renderTimeHistory.count)
        let cacheHitRate = getCacheHitRate()
        
        // Get system info
        let batteryLevel = getBatteryLevel()
        let thermalStateString = getThermalState()
        
        // Update current metrics
        currentMetrics = EnhancedPerformanceMetrics(
            frameRate: avgFrameRate,
            spatialQueryTime: avgQueryTime,
            cacheHitRate: cacheHitRate,
            memoryUsage: memoryUsage,
            nodeCount: currentMetrics.nodeCount,
            quadTreeDepth: currentMetrics.quadTreeDepth,
            bvhNodes: currentMetrics.bvhNodes,
            cpuUsage: cpuUsage,
            renderTime: avgRenderTime,
            timestamp: Date(),
            thermalState: thermalStateString,
            batteryLevel: batteryLevel
        )
        
        // Add to history
        performanceHistory.append(currentMetrics)
        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }
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
    
    private func getCurrentCPUUsage() -> Double {
        var totalUsage: Double = 0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        
        if result == KERN_SUCCESS, let threadList = threadList {
            for i in 0..<Int(threadCount) {
                var threadInfo = thread_basic_info()
                var count = mach_msg_type_number_t(THREAD_INFO_MAX)
                
                let kr = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(
                            threadList[i],
                            thread_flavor_t(THREAD_BASIC_INFO),
                            $0,
                            &count
                        )
                    }
                }
                
                if kr == KERN_SUCCESS && (threadInfo.flags & TH_FLAGS_IDLE) == 0 {
                    totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                }
            }
            
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: threadList),
                vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.stride)
            )
        }
        
        return min(totalUsage * 100.0, 100.0)
    }
    
    private func getBatteryLevel() -> Double {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return Double(UIDevice.current.batteryLevel)
    }
    
    private func getThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
    
    private func updateMemoryPressure(_ memoryUsage: Int) {
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
    
    private func setupThermalStateMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let state = ProcessInfo.processInfo.thermalState
            switch state {
            case .nominal:
                self?.thermalState = .nominal
            case .fair:
                self?.thermalState = .fair
            case .serious:
                self?.thermalState = .serious
            case .critical:
                self?.thermalState = .critical
            @unknown default:
                break
            }
            print("Thermal state changed to: \(state)")
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
                "bvhNodes": currentMetrics.bvhNodes,
                "cpuUsage": currentMetrics.cpuUsage,
                "renderTime": currentMetrics.renderTime,
                "thermalState": currentMetrics.thermalState,
                "batteryLevel": currentMetrics.batteryLevel
            ],
            "statistics": [
                "frameRate": getFrameRateStatistics(),
                "memory": getMemoryStatistics(),
                "cpu": getCPUStatistics(),
                "queryTime": getQueryTimeStatistics(),
                "renderTime": getRenderTimeStatistics(),
                "cacheHitRate": getCacheHitRate()
            ],
            "history": performanceHistory.map { metrics in
                [
                    "timestamp": metrics.timestamp.timeIntervalSince1970,
                    "frameRate": metrics.frameRate,
                    "memoryUsage": metrics.memoryUsage,
                    "cpuUsage": metrics.cpuUsage,
                    "thermalState": metrics.thermalState,
                    "batteryLevel": metrics.batteryLevel
                ]
            }
        ]
        
        do {
            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        } catch {
            print("Failed to export metrics: \(error)")
            return nil
        }
    }
    
    func getPerformanceSummary() -> String {
        let frameStats = getFrameRateStatistics()
        let memoryStats = getMemoryStatistics()
        let cpuStats = getCPUStatistics()
        let queryStats = getQueryTimeStatistics()
        let renderStats = getRenderTimeStatistics()
        
        return """
        Enhanced Performance Summary:
        - Frame Rate: \(String(format: "%.1f", frameStats.average)) FPS (recent: \(String(format: "%.1f", frameStats.recent)))
        - Memory Usage: \(memoryStats.current) MB (peak: \(memoryStats.peak) MB)
        - CPU Usage: \(String(format: "%.1f", cpuStats.current))% (peak: \(String(format: "%.1f", cpuStats.peak))%)
        - Query Time: \(String(format: "%.1f", queryStats.average)) ms
        - Render Time: \(String(format: "%.1f", renderStats.average)) ms
        - Cache Hit Rate: \(String(format: "%.1f", getCacheHitRate() * 100))%
        - Memory Pressure: \(memoryPressure.rawValue)
        - Thermal State: \(thermalState.rawValue)
        - Battery Level: \(String(format: "%.0f", currentMetrics.batteryLevel * 100))%
        - Quality Recommendation: \(getQualityRecommendation())
        """
    }
    
    func resetHistory() {
        frameRateHistory.removeAll()
        memoryHistory.removeAll()
        queryTimeHistory.removeAll()
        renderTimeHistory.removeAll()
        cacheHitHistory.removeAll()
        cpuUsageHistory.removeAll()
        performanceHistory.removeAll()
        frameCount = 0
        cacheHits = 0
        cacheMisses = 0
    }
}

// MARK: - Preview Support
extension EnhancedPerformanceMonitor {
    static var previewMonitor: EnhancedPerformanceMonitor {
        let monitor = EnhancedPerformanceMonitor()
        monitor.currentMetrics = EnhancedPerformanceMetrics(
            frameRate: 58.5,
            spatialQueryTime: 12.3,
            cacheHitRate: 0.85,
            memoryUsage: 180,
            nodeCount: 7500,
            quadTreeDepth: 6,
            bvhNodes: 1250,
            cpuUsage: 45.2,
            renderTime: 8.7,
            timestamp: Date(),
            thermalState: "nominal",
            batteryLevel: 0.85
        )
        monitor.memoryPressure = .normal
        monitor.thermalState = .nominal
        return monitor
    }
}