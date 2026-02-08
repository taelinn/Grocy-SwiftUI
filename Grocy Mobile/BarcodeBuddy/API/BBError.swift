//
//  BBError.swift
//  Grocy Mobile
//
//  BarcodeBuddy API error types
//

import Foundation

enum BBError: LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)
    case unauthorized
    case decodingError(Error)
    case networkError(Error)
    case notFound
    case badRequest(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid BarcodeBuddy server URL"
        case .serverError(let statusCode):
            return "BarcodeBuddy server error (HTTP \(statusCode))"
        case .unauthorized:
            return "Invalid BarcodeBuddy API key"
        case .decodingError(let error):
            return "Failed to parse BarcodeBuddy response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .notFound:
            return "Resource not found on BarcodeBuddy server"
        case .badRequest(let message):
            return "Bad request: \(message)"
        }
    }
}
