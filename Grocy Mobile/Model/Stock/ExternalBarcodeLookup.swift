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
    var quFactorPurchaseToStock: Int?
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
            do { self.locationID = try container.decode(Int.self, forKey: .locationID) } catch { self.locationID = try Int(container.decode(String.self, forKey: .locationID)) }
            do { self.quIDPurchase = try container.decode(Int.self, forKey: .quIDPurchase) } catch { self.quIDPurchase = try Int(container.decode(String.self, forKey: .quIDPurchase)) }
            do { self.quIDStock = try container.decode(Int.self, forKey: .quIDStock) } catch { self.quIDStock = try Int(container.decode(String.self, forKey: .quIDStock)) }
            do { self.quFactorPurchaseToStock = try container.decode(Int.self, forKey: .quFactorPurchaseToStock) } catch { self.quFactorPurchaseToStock = try Int(container.decode(String.self, forKey: .quFactorPurchaseToStock)) }
            self.barcode = try container.decode(String.self, forKey: .barcode)
            self.imageURL = (try? container.decodeIfPresent(String.self, forKey: .imageURL))
        } catch {
            throw APIError.decodingError(error: error)
        }
    }
}
