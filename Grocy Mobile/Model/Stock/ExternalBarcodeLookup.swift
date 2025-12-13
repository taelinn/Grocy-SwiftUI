//
//  ExternalLookupModel.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 22.11.25.
//

import Foundation

// MARK: - ExternalLookupReturn
class ExternalBarcodeLookup: Codable {
    var name: String
    var locationID: Int?
    var quIDPurchase: Int?
    var quIDStock: Int?
    var quFactorPurchaseToStock: Double?
    var barcode: String
    var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case locationID = "location_id"
        case quIDPurchase = "qu_id_purchase"
        case quIDStock = "qu_id_stock"
        case quFactorPurchaseToStock = "__qu_factor_purchase_to_stock"
        case barcode = "__barcode"
        case imageURL = "__image_url"
    }

    required init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.locationID = try container.decodeFlexibleInt(forKey: .locationID)
            self.quIDPurchase = try container.decodeFlexibleInt(forKey: .quIDPurchase)
            self.quIDStock = try container.decodeFlexibleInt(forKey: .quIDStock)
            self.quFactorPurchaseToStock = try container.decodeFlexibleDouble(forKey: .quFactorPurchaseToStock)
            self.barcode = try container.decode(String.self, forKey: .barcode)
            self.imageURL = (try? container.decodeIfPresent(String.self, forKey: .imageURL))
        } catch {
            throw APIError.decodingError(error: error)
        }
    }
}
