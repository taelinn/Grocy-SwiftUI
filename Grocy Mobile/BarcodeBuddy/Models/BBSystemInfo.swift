//
//  BBSystemInfo.swift
//  Grocy Mobile
//
//  BarcodeBuddy system info model
//

import Foundation

// MARK: - System Info
struct BBSystemInfo: Codable {
    let version: String
    let versionInt: String
    
    enum CodingKeys: String, CodingKey {
        case version
        case versionInt = "version_int"
    }
}
