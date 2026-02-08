//
//  BBBarcodeLog.swift
//  Grocy Mobile
//
//  BarcodeBuddy log entry models
//

import Foundation

// MARK: - Barcode Logs Response Data
struct BBBarcodeLogsData: Codable {
    let count: Int
    let logs: [BBBarcodeLog]
}

// MARK: - Barcode Log Entry
struct BBBarcodeLog: Codable, Identifiable {
    let id: Int
    let log: String
}
