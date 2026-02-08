//
//  BBUnknownBarcode.swift
//  Grocy Mobile
//
//  BarcodeBuddy unknown barcode models
//

import Foundation

// MARK: - Unknown Barcodes Response Data
struct BBUnknownBarcodesData: Codable {
    let count: Int
    let barcodes: [BBUnknownBarcode]
}

// MARK: - Unknown Barcode Model
struct BBUnknownBarcode: Codable, Identifiable, Hashable {
    let id: Int
    let barcode: String
    let amount: Int
    let name: String?
    let possibleMatch: Int?
    let isLookedUp: Bool
    let bestBeforeInDays: Int?
    let price: String?
    let altNames: [String]?
}
