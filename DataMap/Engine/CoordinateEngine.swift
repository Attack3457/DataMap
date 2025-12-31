// 📁 File: Engine/CoordinateEngine.swift
// 🎯 DETERMINISTIC, HASH-BASED COORDINATE GENERATION

import Foundation
import CryptoKit
import CoreLocation

// MARK: - Coordinate Engine Protocol
public protocol CoordinateEngineProtocol {
    func coordinate(for path: String, parentCoordinate: CLLocationCoordinate2D?) -> CLLocationCoordinate2D
    func normalizedPosition(for path: String) -> SIMD2<Float>
    func spatialHash(for path: String) -> String
}

// MARK: - Main Coordinate Engine
public final class CoordinateEngine: CoordinateEngineProtocol, @unchecked Sendable {
    
    // MARK: - Configuration
    public struct Configuration {
        var hashAlgorithm: HashAlgorithm = .sha256
        var coordinatePrecision: CoordinatePrecision = .high
        var useSphericalMapping: Bool = true
        var clusterRadius: Double = 0.1 // Degrees
        
        public enum HashAlgorithm {
            case sha256
            case sha512
        }
        
        public enum CoordinatePrecision {
            case low    // 1 decimal place
            case medium // 3 decimal places
            case high   // 5 decimal places
            case exact  // Full double precision
            
            var roundingFactor: Double {
                switch self {
                case .low: return 10.0
                case .medium: return 1000.0
                case .high: return 100000.0
                case .exact: return 1.0
                }
            }
        }
        
        public static let `default` = Configuration()
    }
    
    // MARK: - Properties
    private let configuration: Configuration
    private let cacheQueue = DispatchQueue(label: "coordinate.cache", attributes: .concurrent)
    private var _cache: [String: CLLocationCoordinate2D] = [:]
    
    private var cache: [String: CLLocationCoordinate2D] {
        get {
            cacheQueue.sync { _cache }
        }
        set {
            cacheQueue.async(flags: .barrier) { [weak self] in
                self?._cache = newValue
            }
        }
    }
    
    // MARK: - Initializer
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public API
    
    /// Ana koordinat üretme fonksiyonu
    public func coordinate(for path: String, parentCoordinate: CLLocationCoordinate2D? = nil) -> CLLocationCoordinate2D {
        // Cache kontrolü
        if let cached = cacheQueue.sync(execute: { _cache[path] }) {
            return cached
        }
        
        // Deterministic hash üret
        let hash = generateHash(for: path)
        
        // Hash'ten koordinata dönüşüm
        let coordinate: CLLocationCoordinate2D
        if configuration.useSphericalMapping {
            coordinate = sphericalMapping(from: hash, parent: parentCoordinate)
        } else {
            coordinate = planarMapping(from: hash, parent: parentCoordinate)
        }
        
        // Precision ayarı
        let roundedCoordinate = roundCoordinate(coordinate)
        
        // Cache'e ekle
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?._cache[path] = roundedCoordinate
        }
        return roundedCoordinate
    }
    
    /// Normalized position (0-1 arası) - GPU rendering için
    public func normalizedPosition(for path: String) -> SIMD2<Float> {
        let coord = coordinate(for: path)
        
        // Dünya koordinatlarını 0-1 aralığına normalize et
        let normalizedX = Float((coord.longitude + 180.0) / 360.0)
        let normalizedY = Float((coord.latitude + 90.0) / 180.0)
        
        return SIMD2<Float>(normalizedX, normalizedY)
    }
    
    /// Spatial hash üret (debugging ve grouping için)
    public func spatialHash(for path: String) -> String {
        let hash = generateHash(for: path)
        return hash.hexString.prefix(8).uppercased()
    }
    
    /// Cache'i temizle
    public func clearCache() {
        cache.removeAll()
    }
    
    /// Batch processing - çoklu path'ler için optimize
    public func coordinates(for paths: [String]) async -> [CLLocationCoordinate2D] {
        var results: [CLLocationCoordinate2D] = []
        for path in paths {
            let coord = await coordinate(for: path)
            results.append(coord)
        }
        return results
    }
    
    // MARK: - Private Methods
    
    private func generateHash(for path: String) -> Data {
        let data = Data(path.utf8)
        
        switch configuration.hashAlgorithm {
        case .sha256:
            let digest = SHA256.hash(data: data)
            return Data(digest)
        case .sha512:
            let digest = SHA512.hash(data: data)
            return Data(digest)
        }
    }
    
    /// Küresel dünya haritasına göre mapping
    private func sphericalMapping(from hash: Data, parent: CLLocationCoordinate2D?) -> CLLocationCoordinate2D {
        // Hash'in ilk 8 byte'ını kullan
        let hashBytes = Array(hash.prefix(8))
        
        // 64-bit integer'a çevir
        var hashValue: UInt64 = 0
        for (index, byte) in hashBytes.enumerated() {
            hashValue |= UInt64(byte) << (index * 8)
        }
        
        // Eğer parent varsa, cluster içinde rastgele dağıt
        if let parent = parent {
            return generateClusteredCoordinate(hashValue: hashValue, around: parent)
        }
        
        // Global coordinate generation
        // Hash'ten deterministik lat/lon üret
        let lat = mapToRange(
            value: Double(hashValue & 0xFFFFFFFF),
            fromRange: (0, Double(UInt32.max)),
            toRange: (-90.0, 90.0)
        )
        
        let lon = mapToRange(
            value: Double((hashValue >> 32) & 0xFFFFFFFF),
            fromRange: (0, Double(UInt32.max)),
            toRange: (-180.0, 180.0)
        )
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Düzlemsel mapping (test ve debug için)
    private func planarMapping(from hash: Data, parent: CLLocationCoordinate2D?) -> CLLocationCoordinate2D {
        let hashBytes = Array(hash.prefix(8))
        var hashValue: UInt64 = 0
        for (index, byte) in hashBytes.enumerated() {
            hashValue |= UInt64(byte) << (index * 8)
        }
        
        // Simple 2D mapping
        let x = Double(hashValue & 0xFFFFFFFF) / Double(UInt32.max)
        let y = Double((hashValue >> 32) & 0xFFFFFFFF) / Double(UInt32.max)
        
        // Test area (San Francisco region)
        let lat = 37.7749 + (y - 0.5) * 0.1
        let lon = -122.4194 + (x - 0.5) * 0.1
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Parent coordinate etrafında cluster oluştur
    private func generateClusteredCoordinate(
        hashValue: UInt64,
        around parent: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        // Deterministic offset üret
        let offsetLat = mapToRange(
            value: Double(hashValue & 0xFFFF),
            fromRange: (0, Double(UInt16.max)),
            toRange: (-configuration.clusterRadius, configuration.clusterRadius)
        )
        
        let offsetLon = mapToRange(
            value: Double((hashValue >> 16) & 0xFFFF),
            fromRange: (0, Double(UInt16.max)),
            toRange: (-configuration.clusterRadius, configuration.clusterRadius)
        )
        
        return CLLocationCoordinate2D(
            latitude: parent.latitude + offsetLat,
            longitude: parent.longitude + offsetLon
        )
    }
    
    /// Precision için yuvarlama
    private func roundCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let factor = configuration.coordinatePrecision.roundingFactor
        let lat = round(coordinate.latitude * factor) / factor
        let lon = round(coordinate.longitude * factor) / factor
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Range mapping utility
    private func mapToRange(
        value: Double,
        fromRange: (Double, Double),
        toRange: (Double, Double)
    ) -> Double {
        let normalized = (value - fromRange.0) / (fromRange.1 - fromRange.0)
        return toRange.0 + normalized * (toRange.1 - toRange.0)
    }
}

// MARK: - Data Extension for Hex String
private extension Data {
    var hexString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - SwiftUI Preview Support
extension CoordinateEngine {
    /// Preview için test koordinatları
    static func previewCoordinates() async -> [CLLocationCoordinate2D] {
        let engine = CoordinateEngine()
        let paths = [
            "/Users/test/Documents",
            "/Users/test/Documents/Project1.swift",
            "/Users/test/Downloads",
            "/Users/test/Pictures",
            "/Users/test/Music"
        ]
        return await engine.coordinates(for: paths)
    }
    
    /// Known coordinates for testing
    static let knownCoordinates: [String: CLLocationCoordinate2D] = [
        "Documents": CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // SF
        "Downloads": CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // NYC
        "Pictures": CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),   // London
        "Music": CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),     // Tokyo
        "Projects": CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)     // Paris
    ]
}

// MARK: - Unit Test Support
#if DEBUG
extension CoordinateEngine {
    func testDeterminism() async -> Bool {
        let path = "/test/path/file.txt"
        let coord1 = await coordinate(for: path)
        let coord2 = await coordinate(for: path)
        return coord1.latitude == coord2.latitude &&
               coord1.longitude == coord2.longitude
    }
    
    func testDistribution(count: Int = 1000) async -> (spread: Double, duplicates: Int) {
        var coordinates: Set<String> = []
        var duplicates = 0
        
        for i in 0..<count {
            let path = "/test/path/file_\(i).txt"
            let coord = await coordinate(for: path)
            let key = "\(coord.latitude),\(coord.longitude)"
            
            if coordinates.contains(key) {
                duplicates += 1
            } else {
                coordinates.insert(key)
            }
        }
        
        let spread = Double(coordinates.count) / Double(count)
        return (spread, duplicates)
    }
}
#endif