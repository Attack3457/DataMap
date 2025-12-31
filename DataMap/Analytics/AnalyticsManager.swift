// 📁 File: Analytics/AnalyticsManager.swift
// 🎯 PRIVACY-FRIENDLY ANALYTICS

import Foundation
import UIKit
import Combine

@MainActor
final class AnalyticsManager: ObservableObject {
    
    // MARK: - Types
    struct AnalyticsEvent: Codable, Sendable {
        let name: String
        let timestamp: Date
        let properties: [String: String]
        let sessionId: String
        let appVersion: String
        let deviceModel: String
        let osVersion: String
    }
    
    struct CrashReport: Codable, Sendable {
        let timestamp: Date
        let error: String
        let stackTrace: [String]
        let deviceInfo: String
        let appVersion: String
        let sessionId: String
        let memoryUsage: Int64
        let availableMemory: Int64
    }
    
    struct SessionInfo: Codable, Sendable {
        let sessionId: String
        let startTime: Date
        let endTime: Date?
        let eventCount: Int
        let crashCount: Int
        let deviceModel: String
        let osVersion: String
        let appVersion: String
    }
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private let sessionStart = Date()
    private let sessionId = UUID().uuidString
    private var eventCount = 0
    private var crashCount = 0
    
    // Opt-in analytics (GDPR compliant)
    @Published var isAnalyticsEnabled: Bool {
        didSet {
            userDefaults.set(isAnalyticsEnabled, forKey: "analytics_enabled")
            if isAnalyticsEnabled {
                logEvent("analytics_enabled")
            } else {
                logEvent("analytics_disabled")
                clearAnalyticsData()
            }
        }
    }
    
    @Published var isPerformanceTrackingEnabled: Bool {
        didSet {
            userDefaults.set(isPerformanceTrackingEnabled, forKey: "performance_tracking_enabled")
        }
    }
    
    @Published var isCrashReportingEnabled: Bool {
        didSet {
            userDefaults.set(isCrashReportingEnabled, forKey: "crash_reporting_enabled")
        }
    }
    
    // MARK: - Singleton
    static let shared = AnalyticsManager()
    
    // MARK: - Initialization
    private init() {
        self.isAnalyticsEnabled = userDefaults.bool(forKey: "analytics_enabled")
        self.isPerformanceTrackingEnabled = userDefaults.bool(forKey: "performance_tracking_enabled")
        self.isCrashReportingEnabled = userDefaults.bool(forKey: "crash_reporting_enabled")
        
        setupCrashReporting()
        startSession()
    }
    
    deinit {
        // Note: Cannot call async methods in deinit
        // endSession() should be called manually before deallocation
    }
    
    // MARK: - Public API
    
    func logEvent(_ name: String, properties: [String: String] = [:]) {
        guard isAnalyticsEnabled else { return }
        
        let event = AnalyticsEvent(
            name: name,
            timestamp: Date(),
            properties: properties,
            sessionId: sessionId,
            appVersion: getAppVersion(),
            deviceModel: getDeviceModel(),
            osVersion: getOSVersion()
        )
        
        storeEvent(event)
        eventCount += 1
        
        print("📊 Analytics: \(name) - \(properties)")
    }
    
    func logPerformanceMetric(_ name: String, value: Double, unit: String = "") {
        guard isAnalyticsEnabled && isPerformanceTrackingEnabled else { return }
        
        logEvent("performance_metric", properties: [
            "metric_name": name,
            "value": String(value),
            "unit": unit,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func logUserAction(_ action: String, context: String = "") {
        guard isAnalyticsEnabled else { return }
        
        logEvent("user_action", properties: [
            "action": action,
            "context": context,
            "screen": getCurrentScreen()
        ])
    }
    
    func logError(_ error: Error, context: String = "") {
        guard isAnalyticsEnabled else { return }
        
        logEvent("error", properties: [
            "error_description": error.localizedDescription,
            "error_domain": (error as NSError).domain,
            "error_code": String((error as NSError).code),
            "context": context
        ])
    }
    
    func logCrash(_ exception: NSException) {
        guard isCrashReportingEnabled else { return }
        
        let crashReport = CrashReport(
            timestamp: Date(),
            error: exception.description,
            stackTrace: exception.callStackSymbols,
            deviceInfo: getDeviceInfo(),
            appVersion: getAppVersion(),
            sessionId: sessionId,
            memoryUsage: getCurrentMemoryUsage(),
            availableMemory: getAvailableMemory()
        )
        
        storeCrashReport(crashReport)
        crashCount += 1
        
        print("💥 Crash Report: \(exception.name) - \(exception.reason ?? "Unknown")")
    }
    
    // MARK: - Common Events
    
    func logAppLaunched() {
        logEvent("app_launched", properties: [
            "launch_time": ISO8601DateFormatter().string(from: Date()),
            "is_first_launch": String(isFirstLaunch())
        ])
    }
    
    func logScanStarted(path: String) {
        logEvent("scan_started", properties: [
            "path_type": getPathType(path),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func logScanCompleted(fileCount: Int, duration: TimeInterval, path: String) {
        logEvent("scan_completed", properties: [
            "file_count": String(fileCount),
            "duration": String(format: "%.2f", duration),
            "files_per_second": String(format: "%.2f", Double(fileCount) / duration),
            "path_type": getPathType(path)
        ])
    }
    
    func logMapInteraction(zoomLevel: String, nodeCount: Int, interactionType: String) {
        logEvent("map_interaction", properties: [
            "zoom_level": zoomLevel,
            "visible_nodes": String(nodeCount),
            "interaction_type": interactionType
        ])
    }
    
    func logSearchPerformed(query: String, resultCount: Int, duration: TimeInterval) {
        logEvent("search_performed", properties: [
            "query_length": String(query.count),
            "result_count": String(resultCount),
            "search_duration": String(format: "%.3f", duration),
            "has_results": String(resultCount > 0)
        ])
    }
    
    func logFeatureUsed(_ feature: String, context: [String: String] = [:]) {
        var properties = context
        properties["feature"] = feature
        properties["usage_timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        logEvent("feature_used", properties: properties)
    }
    
    // MARK: - Data Export & Privacy
    
    func exportAnalyticsData() -> Data? {
        let events = loadEvents()
        let crashes = loadCrashReports()
        let sessions = loadSessions()
        
        let exportData: [String: Any] = [
            "export_timestamp": Date().timeIntervalSince1970,
            "user_consent": [
                "analytics_enabled": isAnalyticsEnabled,
                "performance_tracking_enabled": isPerformanceTrackingEnabled,
                "crash_reporting_enabled": isCrashReportingEnabled
            ],
            "events": events.map { event in
                [
                    "name": event.name,
                    "timestamp": event.timestamp.timeIntervalSince1970,
                    "properties": event.properties,
                    "session_id": event.sessionId
                ]
            },
            "crash_reports": crashes.map { crash in
                [
                    "timestamp": crash.timestamp.timeIntervalSince1970,
                    "error": crash.error,
                    "session_id": crash.sessionId,
                    "device_info": crash.deviceInfo
                ]
            },
            "sessions": sessions.map { session in
                [
                    "session_id": session.sessionId,
                    "start_time": session.startTime.timeIntervalSince1970,
                    "end_time": session.endTime?.timeIntervalSince1970,
                    "event_count": session.eventCount,
                    "crash_count": session.crashCount
                ]
            }
        ]
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    func clearAnalyticsData() {
        userDefaults.removeObject(forKey: "analytics_events")
        userDefaults.removeObject(forKey: "crash_reports")
        userDefaults.removeObject(forKey: "analytics_sessions")
        
        print("🗑️ Analytics data cleared")
    }
    
    func getDataSummary() -> String {
        let events = loadEvents()
        let crashes = loadCrashReports()
        let sessions = loadSessions()
        
        return """
        Analytics Data Summary:
        - Total Events: \(events.count)
        - Crash Reports: \(crashes.count)
        - Sessions: \(sessions.count)
        - Current Session: \(sessionId)
        - Data Collection: \(isAnalyticsEnabled ? "Enabled" : "Disabled")
        - Performance Tracking: \(isPerformanceTrackingEnabled ? "Enabled" : "Disabled")
        - Crash Reporting: \(isCrashReportingEnabled ? "Enabled" : "Disabled")
        """
    }
    
    // MARK: - Private Methods
    
    private func setupCrashReporting() {
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                AnalyticsManager.shared.logCrash(exception)
            }
        }
    }
    
    private func startSession() {
        let session = SessionInfo(
            sessionId: sessionId,
            startTime: sessionStart,
            endTime: nil,
            eventCount: 0,
            crashCount: 0,
            deviceModel: getDeviceModel(),
            osVersion: getOSVersion(),
            appVersion: getAppVersion()
        )
        
        storeSession(session)
        logEvent("session_started")
    }
    
    private func endSession() {
        let session = SessionInfo(
            sessionId: sessionId,
            startTime: sessionStart,
            endTime: Date(),
            eventCount: eventCount,
            crashCount: crashCount,
            deviceModel: getDeviceModel(),
            osVersion: getOSVersion(),
            appVersion: getAppVersion()
        )
        
        storeSession(session)
        logEvent("session_ended", properties: [
            "session_duration": String(Date().timeIntervalSince(sessionStart)),
            "event_count": String(eventCount),
            "crash_count": String(crashCount)
        ])
    }
    
    private func storeEvent(_ event: AnalyticsEvent) {
        var events = loadEvents()
        events.append(event)
        
        // Keep only last 10000 events
        if events.count > 10000 {
            events.removeFirst(events.count - 10000)
        }
        
        if let data = try? JSONEncoder().encode(events) {
            userDefaults.set(data, forKey: "analytics_events")
        }
    }
    
    private func storeCrashReport(_ crash: CrashReport) {
        var crashes = loadCrashReports()
        crashes.append(crash)
        
        // Keep only last 100 crash reports
        if crashes.count > 100 {
            crashes.removeFirst(crashes.count - 100)
        }
        
        if let data = try? JSONEncoder().encode(crashes) {
            userDefaults.set(data, forKey: "crash_reports")
        }
    }
    
    private func storeSession(_ session: SessionInfo) {
        var sessions = loadSessions()
        
        // Update existing session or add new one
        if let index = sessions.firstIndex(where: { $0.sessionId == session.sessionId }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        
        // Keep only last 50 sessions
        if sessions.count > 50 {
            sessions.removeFirst(sessions.count - 50)
        }
        
        if let data = try? JSONEncoder().encode(sessions) {
            userDefaults.set(data, forKey: "analytics_sessions")
        }
    }
    
    private func loadEvents() -> [AnalyticsEvent] {
        guard let data = userDefaults.data(forKey: "analytics_events"),
              let events = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    private func loadCrashReports() -> [CrashReport] {
        guard let data = userDefaults.data(forKey: "crash_reports"),
              let crashes = try? JSONDecoder().decode([CrashReport].self, from: data) else {
            return []
        }
        return crashes
    }
    
    private func loadSessions() -> [SessionInfo] {
        guard let data = userDefaults.data(forKey: "analytics_sessions"),
              let sessions = try? JSONDecoder().decode([SessionInfo].self, from: data) else {
            return []
        }
        return sessions
    }
    
    // MARK: - System Info
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    private func getAppVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private func getDeviceInfo() -> String {
        return "\(getDeviceModel()) - iOS \(getOSVersion())"
    }
    
    private func getCurrentScreen() -> String {
        // This would be implemented based on your navigation system
        return "unknown"
    }
    
    private func getPathType(_ path: String) -> String {
        if path.contains("/Documents") { return "documents" }
        if path.contains("/Downloads") { return "downloads" }
        if path.contains("/Pictures") { return "pictures" }
        if path.contains("/Music") { return "music" }
        if path.contains("/Desktop") { return "desktop" }
        return "other"
    }
    
    private func isFirstLaunch() -> Bool {
        let hasLaunchedBefore = userDefaults.bool(forKey: "has_launched_before")
        if !hasLaunchedBefore {
            userDefaults.set(true, forKey: "has_launched_before")
            return true
        }
        return false
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func getAvailableMemory() -> Int64 {
        return Int64(ProcessInfo.processInfo.physicalMemory)
    }
}

// MARK: - Privacy Extensions
extension AnalyticsManager {
    
    func showPrivacyDialog() -> Bool {
        // This would show a privacy dialog to the user
        // For now, return current state
        return isAnalyticsEnabled
    }
    
    func getPrivacyPolicyText() -> String {
        return """
        Privacy Policy - DataMap Pro
        
        We respect your privacy and are committed to protecting your personal data.
        
        DATA COLLECTION:
        • Analytics data is collected only with your explicit consent
        • All data is stored locally on your device
        • No personal information is collected
        • No data is transmitted to external servers
        
        WHAT WE COLLECT:
        • App usage statistics (if enabled)
        • Performance metrics (if enabled)
        • Crash reports (if enabled)
        • Device model and OS version (for compatibility)
        
        YOUR RIGHTS:
        • You can disable data collection at any time
        • You can export all collected data
        • You can delete all collected data
        • You can view what data has been collected
        
        CONTACT:
        For questions about this privacy policy, contact us at privacy@datamap.app
        
        Last updated: \(Date().formatted(date: .abbreviated, time: .omitted))
        """
    }
}