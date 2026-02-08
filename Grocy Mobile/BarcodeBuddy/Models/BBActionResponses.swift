//
//  BBActionResponses.swift
//  Grocy Mobile
//
//  BarcodeBuddy action response models
//

import Foundation

// MARK: - Delete Barcode Response
struct BBDeleteResponse: Codable {
    let deleted: Int
}

// MARK: - Associate Barcode Response
struct BBAssociateResponse: Codable {
    let associated: Bool
    let barcodeId: Int
    let barcode: String
    let productId: Int
}
