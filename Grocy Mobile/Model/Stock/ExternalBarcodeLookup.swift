//
//  ExternalLookupModel.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 22.11.25.
//

import Foundation

// MARK: - ExternalLookupReturn
struct ExternalBarcodeLookup: Codable {
    let name: String
    let locationID: Int
    let quIDPurchase: Int
    let quIDStock: Int
    let quFactorPurchaseToStock: Int
    let barcode: String
    let imageURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case locationID = "location_id"
        case quIDPurchase = "qu_id_purchase"
        case quIDStock = "qu_id_stock"
        case quFactorPurchaseToStock = "__qu_factor_purchase_to_stock"
        case barcode = "__barcode"
        case imageURL = "__image_url"
    }
}
