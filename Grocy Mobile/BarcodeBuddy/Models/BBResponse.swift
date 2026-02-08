//
//  BBResponse.swift
//  Grocy Mobile
//
//  BarcodeBuddy API response models
//

import Foundation

// MARK: - Generic BB API Response Wrapper
struct BBResponse<T: Codable>: Codable {
    let data: T
    let result: BBResult
}

struct BBResult: Codable {
    let result: String      // "OK" or error message
    let httpCode: Int
    
    enum CodingKeys: String, CodingKey {
        case result
        case httpCode = "http_code"
    }
}
