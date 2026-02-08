//
//  BarcodeBuddyCache.swift
//  Grocy Mobile
//
//  Cached BarcodeBuddy data for widgets
//

import Foundation
import SwiftData

@Model
class BarcodeBuddyCache {
    var newBarcodesCount: Int          // Barcodes that were looked up successfully
    var unknownBarcodesCount: Int      // Barcodes that couldn't be looked up
    var totalCount: Int                // Total of both
    var lastUpdated: Date
    
    init(newBarcodesCount: Int = 0, unknownBarcodesCount: Int = 0, lastUpdated: Date = Date()) {
        self.newBarcodesCount = newBarcodesCount
        self.unknownBarcodesCount = unknownBarcodesCount
        self.totalCount = newBarcodesCount + unknownBarcodesCount
        self.lastUpdated = lastUpdated
    }
}
