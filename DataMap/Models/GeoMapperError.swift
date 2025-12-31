// 📁 File: Models/GeoMapperError.swift
// 🎯 ERROR TYPES FOR GEOMAPPER

import Foundation

// MARK: - GeoMapper Error Types
public enum GeoMapperError: Error, LocalizedError, Sendable {
    case fileSystemAccess(String)
    case coordinateGeneration(String)
    case scanningFailed(String)
    case renderingError(String)
    case memoryError(String)
    case configurationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileSystemAccess(let message):
            return "File system access error: \(message)"
        case .coordinateGeneration(let message):
            return "Coordinate generation error: \(message)"
        case .scanningFailed(let message):
            return "File scanning failed: \(message)"
        case .renderingError(let message):
            return "Rendering error: \(message)"
        case .memoryError(let message):
            return "Memory error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .fileSystemAccess:
            return "Check file permissions and try again."
        case .coordinateGeneration:
            return "Verify the path format and coordinate engine configuration."
        case .scanningFailed:
            return "Ensure the directory exists and is accessible."
        case .renderingError:
            return "Try restarting the app or reducing the data set size."
        case .memoryError:
            return "Close other apps to free up memory."
        case .configurationError:
            return "Check the app configuration settings."
        }
    }
}