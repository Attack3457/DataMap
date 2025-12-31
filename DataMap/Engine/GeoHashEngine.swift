// 📁 File: Engine/GeoHashEngine.swift
// 🎯 ADVANCED SPATIAL HASHING WITH MORTON ORDERING

import Foundation
import CryptoKit
import CoreLocation

// MARK: - 128-bit Integer
struct UInt128: Hashable, Sendable {
    var high: UInt64
    var low: UInt64
    
    init(high: UInt64 = 0, low: UInt64 = 0) {
        self.high = high
        self.low = low
    }
    
    init(_ value: UInt64) {
        self.high = 0
        self.low = value
    }
    
    static func + (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let (low, overflow) = lhs.low.addingReportingOverflow(rhs.low)
        let high = lhs.high + rhs.high + (overflow ? 1 : 0)
        return UInt128(high: high, low: low)
    }
    
    static func * (lhs: UInt128, rhs: UInt64) -> UInt128 {
        let lowProduct = lhs.low.multipliedFullWidth(by: rhs)
        let highProduct = lhs.high * rhs
        return UInt128(high: highProduct + lowProduct.high, low: lowProduct.low)
    }
}

// MARK: - GeoHash Engine
actor GeoHashEngine {
    
    // MARK: - Configuration
    struct Configuration: Sendable {
        var hashAlgorithm: HashAlgorithm = .sha3_512
        var coordinatePrecision: CoordinatePrecision = .high
        var useFibonacciLattice: Bool = true
        var clusterRadius: Double = 0.001 // Degrees
        var useHilbertCurve: Bool = false
        
        enum HashAlgorithm {
            case sha256, sha512, sha3_512
        }
        
        enum CoordinatePrecision {
            case low, medium, high, exact
            
            var decimalPlaces: Int {
                switch self {
                case .low: return 3
                case .medium: return 5
                case .high: return 7
                case .exact: return 15
                }
            }
        }
        
        static let `default` = Configuration()
    }
    
    // MARK: - Properties
    private let configuration: Configuration
    private var cache: [String: CLLocationCoordinate2D] = [:]
    private var spatialHashCache: [String: String] = [:]
    
    // MARK: - Constants
    private let goldenRatio = (1.0 + sqrt(5.0)) / 2.0
    private let phi = 1.618033988749895 // Golden ratio
    
    // MARK: - Initialization
    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public API
    
    /// Generate deterministic coordinate from file path
    func coordinate(for path: String, parentCoordinate: CLLocationCoordinate2D? = nil) async -> CLLocationCoordinate2D {
        // Check cache first
        if let cached = cache[path] {
            return cached
        }
        
        // Generate spatial hash
        let spatialHash = await generateSpatialHash(for: path)
        
        // Convert to coordinate
        let coordinate: CLLocationCoordinate2D
        if configuration.useFibonacciLattice {
            coordinate = fibonacciLatticeMapping(from: spatialHash, parent: parentCoordinate)
        } else if configuration.useHilbertCurve {
            coordinate = hilbertCurveMapping(from: spatialHash, parent: parentCoordinate)
        } else {
            coordinate = sphericalMapping(from: spatialHash, parent: parentCoordinate)
        }
        
        // Apply precision
        let roundedCoordinate = applyPrecision(to: coordinate)
        
        // Cache result
        cache[path] = roundedCoordinate
        return roundedCoordinate
    }
    
    /// Generate normalized position (0-1 range)
    func normalizedPosition(for path: String) async -> SIMD2<Float> {
        let coordinate = await coordinate(for: path)
        return SIMD2<Float>(
            Float((coordinate.longitude + 180.0) / 360.0),
            Float((coordinate.latitude + 90.0) / 180.0)
        )
    }
    
    /// Generate spatial hash string
    func spatialHash(for path: String) async -> String {
        if let cached = spatialHashCache[path] {
            return cached
        }
        
        let hash = await generateSpatialHash(for: path)
        let hashString = String(format: "%016llx%016llx", hash.high, hash.low)
        
        spatialHashCache[path] = hashString
        return hashString
    }
    
    /// Generate Morton code (Z-order curve)
    func mortonCode(for path: String) async -> UInt64 {
        let coordinate = await coordinate(for: path)
        
        // Convert to normalized coordinates (0-1)
        let x = UInt32((coordinate.longitude + 180.0) / 360.0 * Double(UInt32.max))
        let y = UInt32((coordinate.latitude + 90.0) / 180.0 * Double(UInt32.max))
        
        return Self.interleaveBits(x, y)
    }
    
    /// Generate Hilbert curve index
    func hilbertIndex(for path: String, order: Int = 16) async -> UInt64 {
        let coordinate = await coordinate(for: path)
        
        // Convert to grid coordinates
        let gridSize = 1 << order
        let x = Int((coordinate.longitude + 180.0) / 360.0 * Double(gridSize))
        let y = Int((coordinate.latitude + 90.0) / 180.0 * Double(gridSize))
        
        return Self.hilbertXYToIndex(x: x, y: y, order: order)
    }
    
    /// Clear caches
    func clearCache() {
        cache.removeAll()
        spatialHashCache.removeAll()
    }
    
    /// Batch processing
    func coordinates(for paths: [String]) async -> [CLLocationCoordinate2D] {
        var results: [CLLocationCoordinate2D] = []
        results.reserveCapacity(paths.count)
        
        for path in paths {
            let coord = await coordinate(for: path)
            results.append(coord)
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func generateSpatialHash(for path: String) async -> UInt128 {
        let data = Data(path.utf8)
        
        switch configuration.hashAlgorithm {
        case .sha256:
            let digest = SHA256.hash(data: data)
            return digestToUInt128(digest)
        case .sha512:
            let digest = SHA512.hash(data: data)
            return digestToUInt128(digest)
        case .sha3_512:
            // For now, use SHA512 as SHA3 is not available in CryptoKit
            let digest = SHA512.hash(data: data)
            return digestToUInt128(digest)
        }
    }
    
    private func digestToUInt128<D: Digest>(_ digest: D) -> UInt128 {
        let bytes = Array(digest.prefix(16))
        return bytesToUInt128(bytes)
    }
    
    private func bytesToUInt128(_ bytes: [UInt8]) -> UInt128 {
        var high: UInt64 = 0
        var low: UInt64 = 0
        
        for (i, byte) in bytes.enumerated() {
            if i < 8 {
                high = (high << 8) | UInt64(byte)
            } else {
                low = (low << 8) | UInt64(byte)
            }
        }
        
        return UInt128(high: high, low: low)
    }
    
    // MARK: - Mapping Algorithms
    
    /// Fibonacci lattice mapping for even distribution on sphere
    private func fibonacciLatticeMapping(from hash: UInt128, parent: CLLocationCoordinate2D?) -> CLLocationCoordinate2D {
        if let parent = parent {
            return generateClusteredCoordinate(from: hash, around: parent)
        }
        
        // Use golden ratio for Fibonacci lattice
        let n = Double(hash.low % 100000) // Use modulo to keep numbers manageable
        
        // Map to sphere using Fibonacci lattice
        let i = Double(hash.high % 10000) // Use first 10000 points
        let phi = acos(1.0 - 2.0 * (i + 0.5) / 10000.0)
        let theta = 2.0 * .pi * i / goldenRatio
        
        let lat = 90.0 - (phi * 180.0 / .pi)
        let lon = (theta * 180.0 / .pi).truncatingRemainder(dividingBy: 360.0) - 180.0
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Hilbert curve mapping for spatial locality
    private func hilbertCurveMapping(from hash: UInt128, parent: CLLocationCoordinate2D?) -> CLLocationCoordinate2D {
        if let parent = parent {
            return generateClusteredCoordinate(from: hash, around: parent)
        }
        
        let order = 16 // 2^16 x 2^16 grid
        let index = hash.low % (1 << (order * 2))
        
        let (x, y) = Self.hilbertIndexToXY(index: UInt64(index), order: order)
        
        let lat = Double(y) / Double(1 << order) * 180.0 - 90.0
        let lon = Double(x) / Double(1 << order) * 360.0 - 180.0
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Traditional spherical mapping
    private func sphericalMapping(from hash: UInt128, parent: CLLocationCoordinate2D?) -> CLLocationCoordinate2D {
        if let parent = parent {
            return generateClusteredCoordinate(from: hash, around: parent)
        }
        
        // Map hash bits to latitude/longitude
        let latBits = UInt32(truncatingIfNeeded: hash.low)
        let lonBits = UInt32(truncatingIfNeeded: hash.low >> 32)
        
        let lat = Double(latBits) / Double(UInt32.max) * 180.0 - 90.0
        let lon = Double(lonBits) / Double(UInt32.max) * 360.0 - 180.0
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// Generate coordinate clustered around parent
    private func generateClusteredCoordinate(from hash: UInt128, around parent: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let latOffset = Double(Int64(hash.low) % 1000) / 1000.0 * configuration.clusterRadius * 2 - configuration.clusterRadius
        let lonOffset = Double(Int64(hash.high) % 1000) / 1000.0 * configuration.clusterRadius * 2 - configuration.clusterRadius
        
        return CLLocationCoordinate2D(
            latitude: parent.latitude + latOffset,
            longitude: parent.longitude + lonOffset
        )
    }
    
    /// Apply precision rounding
    private func applyPrecision(to coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let factor = pow(10.0, Double(configuration.coordinatePrecision.decimalPlaces))
        let lat = round(coordinate.latitude * factor) / factor
        let lon = round(coordinate.longitude * factor) / factor
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // MARK: - Morton Ordering (Z-order curve)
    
    /// Interleave bits for Morton code
    static func interleaveBits(_ x: UInt32, _ y: UInt32) -> UInt64 {
        var result: UInt64 = 0
        for i in 0..<32 {
            result |= (UInt64(x >> i) & 1) << (2 * i)
            result |= (UInt64(y >> i) & 1) << (2 * i + 1)
        }
        return result
    }
    
    /// Deinterleave Morton code to coordinates
    static func deinterleaveBits(_ morton: UInt64) -> (UInt32, UInt32) {
        var x: UInt32 = 0
        var y: UInt32 = 0
        
        for i in 0..<32 {
            x |= UInt32((morton >> (2 * i)) & 1) << i
            y |= UInt32((morton >> (2 * i + 1)) & 1) << i
        }
        
        return (x, y)
    }
    
    // MARK: - Hilbert Curve Implementation
    
    /// Convert Hilbert index to XY coordinates
    static func hilbertIndexToXY(index: UInt64, order: Int) -> (Int, Int) {
        var x = 0
        var y = 0
        var t = index
        
        for s in stride(from: 1, through: order, by: 1) {
            let rx = 1 & (t >> 1)
            let ry = 1 & (t ^ rx)
            
            let (newX, newY) = rot(n: 1 << s, x: x, y: y, rx: Int(rx), ry: Int(ry))
            x = newX
            y = newY
            
            x += Int(rx) << (s - 1)
            y += Int(ry) << (s - 1)
            
            t >>= 2
        }
        
        return (x, y)
    }
    
    /// Convert XY coordinates to Hilbert index
    static func hilbertXYToIndex(x: Int, y: Int, order: Int) -> UInt64 {
        var index: UInt64 = 0
        var x = x
        var y = y
        
        for s in stride(from: order, through: 1, by: -1) {
            let rx = (x >> (s - 1)) & 1
            let ry = (y >> (s - 1)) & 1
            
            index += UInt64((3 * rx) ^ ry) << UInt64(2 * (s - 1))
            
            let (newX, newY) = rot(n: 1 << s, x: x, y: y, rx: rx, ry: ry)
            x = newX
            y = newY
        }
        
        return index
    }
    
    /// Rotate/flip quadrant appropriately
    private static func rot(n: Int, x: Int, y: Int, rx: Int, ry: Int) -> (Int, Int) {
        if ry == 0 {
            if rx == 1 {
                return (n - 1 - y, n - 1 - x)
            }
            return (y, x)
        }
        return (x, y)
    }
    
    // MARK: - Geohash Implementation
    
    /// Generate standard geohash string
    func geohash(for path: String, precision: Int = 12) async -> String {
        let coordinate = await coordinate(for: path)
        return Self.encodeGeohash(latitude: coordinate.latitude, longitude: coordinate.longitude, precision: precision)
    }
    
    /// Encode coordinate to geohash
    static func encodeGeohash(latitude: Double, longitude: Double, precision: Int) -> String {
        let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"
        
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var isEven = true
        var bit = 0
        var ch = 0
        var result = ""
        
        while result.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    ch |= (1 << (4 - bit))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    ch |= (1 << (4 - bit))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            
            isEven = !isEven
            
            if bit < 4 {
                bit += 1
            } else {
                result += String(base32[base32.index(base32.startIndex, offsetBy: ch)])
                bit = 0
                ch = 0
            }
        }
        
        return result
    }
}

// MARK: - Performance Extensions
extension GeoHashEngine {
    
    /// Get cache statistics
    func getCacheStatistics() -> (coordinateCache: Int, spatialHashCache: Int) {
        return (cache.count, spatialHashCache.count)
    }
    
    /// Get memory usage
    func getMemoryUsage() -> Int {
        let coordinateCacheSize = cache.count * (MemoryLayout<String>.stride + MemoryLayout<CLLocationCoordinate2D>.stride)
        let spatialHashCacheSize = spatialHashCache.count * MemoryLayout<String>.stride * 2
        return coordinateCacheSize + spatialHashCacheSize
    }
    
    /// Optimize cache by removing old entries
    func optimizeCache(maxSize: Int = 10000) {
        if cache.count > maxSize {
            let keysToRemove = Array(cache.keys.prefix(cache.count - maxSize))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
        
        if spatialHashCache.count > maxSize {
            let keysToRemove = Array(spatialHashCache.keys.prefix(spatialHashCache.count - maxSize))
            for key in keysToRemove {
                spatialHashCache.removeValue(forKey: key)
            }
        }
    }
}