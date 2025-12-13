//
//  ProductDetailsModel.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 25.11.20.
//

import Foundation
import SwiftData

// MARK: - StockProductDetails

@Model
class StockProductDetails: Codable {
    var product: MDProduct? = nil
    var productID: Int
    var productBarcodes: [MDProductBarcode?] = []
    var productBarcodesIDs: [Int]
    var lastPurchased: Date?
    var lastUsed: Date?
    var stockAmount: Double
    var stockValue: Double?
    var stockAmountOpened: Double?
    var stockAmountAggregated: Double?
    var stockAmountOpenedAggregated: Double?
    var quantityUnitStock: MDQuantityUnit? = nil
    var quantityUnitStockID: Int
    var defaultQuantityUnitPurchase: MDQuantityUnit? = nil
    var defaultQuantityUnitPurchaseID: Int
    var defaultQuantityUnitConsume: MDQuantityUnit? = nil
    var defaultQuantityUnitConsumeID: Int
    var quantityUnitPrice: MDQuantityUnit? = nil
    var quantityUnitPriceID: Int
    var lastPrice: Double?
    var avgPrice: Double?
    var oldestPrice: Double?
    var currentPrice: Double?
    var lastStoreID: Int?
    var defaultStoreID: Int?
    var nextDueDate: String
    var location: MDLocation?
    var locationID: Int
    var averageShelfLifeDays: Int?
    var spoilRatePercent: Double
    var isAggregatedAmount: Bool
    var hasChilds: Bool
    var defaultConsumeLocation: MDLocation?
    var defaultConsumeLocationID: Int?
    var quConversionFactorPurchaseToStock: Double
    var quConversionFactorPriceToStock: Double

    enum CodingKeys: String, CodingKey {
        case product
        case productBarcodes = "product_barcodes"
        case lastPurchased = "last_purchased"
        case lastUsed = "last_used"
        case stockAmount = "stock_amount"
        case stockValue = "stock_value"
        case stockAmountOpened = "stock_amount_opened"
        case stockAmountAggregated = "stock_amount_aggregated"
        case stockAmountOpenedAggregated = "stock_amount_opened_aggregated"
        case quantityUnitStock = "quantity_unit_stock"
        case defaultQuantityUnitPurchase = "default_quantity_unit_purchase"
        case defaultQuantityUnitConsume = "default_quantity_unit_consume"
        case quantityUnitPrice = "quantity_unit_price"
        case lastPrice = "last_price"
        case avgPrice = "avg_price"
        case oldestPrice = "oldest_price"
        case currentPrice = "current_price"
        case lastStoreID = "last_shopping_location_id"
        case defaultStoreID = "default_shopping_location_id"
        case nextDueDate = "next_due_date"
        case location
        case averageShelfLifeDays = "average_shelf_life_days"
        case spoilRatePercent = "spoil_rate_percent"
        case isAggregatedAmount = "is_aggregated_amount"
        case hasChilds = "has_childs"
        case defaultConsumeLocation = "default_consume_location"
        case quConversionFactorPurchaseToStock = "qu_conversion_factor_purchase_to_stock"
        case quConversionFactorPriceToStock = "qu_conversion_factor_price_to_stock"
    }

    required init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let product = try container.decode(MDProduct.self, forKey: .product)
            self.productID = product.id
            let productBarcodes = try container.decode([MDProductBarcode].self, forKey: .productBarcodes)
            self.productBarcodesIDs = productBarcodes.map({ $0.id })
            self.lastPurchased = getDateFromString(try? container.decodeIfPresent(String.self, forKey: .lastPurchased))
            self.lastUsed = getDateFromString(try? container.decodeIfPresent(String.self, forKey: .lastUsed))
            self.stockAmount = try container.decodeFlexibleDouble(forKey: .stockAmount)
            self.stockValue = try container.decodeFlexibleDoubleIfPresent(forKey: .stockValue)
            self.stockAmountOpened = try container.decodeFlexibleDoubleIfPresent(forKey: .stockAmountOpened)
            self.stockAmountAggregated = try container.decodeFlexibleDoubleIfPresent(forKey: .stockAmountAggregated)
            self.stockAmountOpenedAggregated = try container.decodeFlexibleDoubleIfPresent(forKey: .stockAmountOpenedAggregated)
            let quantityUnitStock = try container.decode(MDQuantityUnit.self, forKey: .quantityUnitStock)
            self.quantityUnitStockID = quantityUnitStock.id
            let defaultQuantityUnitPurchase = try container.decode(MDQuantityUnit.self, forKey: .defaultQuantityUnitPurchase)
            self.defaultQuantityUnitPurchaseID = defaultQuantityUnitPurchase.id
            let defaultQuantityUnitConsume = try container.decode(MDQuantityUnit.self, forKey: .defaultQuantityUnitConsume)
            self.defaultQuantityUnitConsumeID = defaultQuantityUnitConsume.id
            let quantityUnitPrice = try container.decode(MDQuantityUnit.self, forKey: .quantityUnitPrice)
            self.quantityUnitPriceID = quantityUnitPrice.id
            self.lastPrice = try container.decodeFlexibleDoubleIfPresent(forKey: .lastPrice)
            self.avgPrice = try container.decodeFlexibleDoubleIfPresent(forKey: .avgPrice)
            self.oldestPrice = try container.decodeFlexibleDoubleIfPresent(forKey: .oldestPrice)
            self.currentPrice = try container.decodeFlexibleDoubleIfPresent(forKey: .currentPrice)
            self.lastStoreID = try container.decodeFlexibleIntIfPresent(forKey: .lastStoreID)
            self.defaultStoreID = try container.decodeFlexibleIntIfPresent(forKey: .defaultStoreID)
            self.nextDueDate = try container.decode(String.self, forKey: .nextDueDate)
            let location = try container.decode(MDLocation.self, forKey: .location)
            self.locationID = location.id
            self.averageShelfLifeDays = try container.decodeFlexibleIntIfPresent(forKey: .averageShelfLifeDays)
            self.spoilRatePercent = try container.decodeFlexibleDouble(forKey: .spoilRatePercent)
            self.isAggregatedAmount = try container.decodeFlexibleBool(forKey: .isAggregatedAmount)
            self.hasChilds = try container.decodeFlexibleBool(forKey: .hasChilds)
            let defaultConsumeLocation = try container.decodeIfPresent(MDLocation.self, forKey: .defaultConsumeLocation)
            self.defaultConsumeLocationID = defaultConsumeLocation?.id
            self.quConversionFactorPurchaseToStock = try container.decodeFlexibleDouble(forKey: .quConversionFactorPurchaseToStock)
            self.quConversionFactorPriceToStock = try container.decodeFlexibleDouble(forKey: .quConversionFactorPriceToStock)
        } catch {
            throw APIError.decodingError(error: error)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(productID, forKey: .product)
        try container.encode(productBarcodesIDs, forKey: .productBarcodes)
        try container.encode(lastPurchased, forKey: .lastPurchased)
        try container.encode(lastUsed, forKey: .lastUsed)
        try container.encode(stockAmount, forKey: .stockAmount)
        try container.encode(stockValue, forKey: .stockValue)
        try container.encode(stockAmountOpened, forKey: .stockAmountOpened)
        try container.encode(stockAmountAggregated, forKey: .stockAmountAggregated)
        try container.encode(stockAmountOpenedAggregated, forKey: .stockAmountOpenedAggregated)
        try container.encode(quantityUnitStockID, forKey: .quantityUnitStock)
        try container.encode(defaultQuantityUnitPurchaseID, forKey: .defaultQuantityUnitPurchase)
        try container.encode(defaultQuantityUnitConsumeID, forKey: .defaultQuantityUnitConsume)
        try container.encode(quantityUnitPriceID, forKey: .quantityUnitPrice)
        try container.encode(lastPrice, forKey: .lastPrice)
        try container.encode(avgPrice, forKey: .avgPrice)
        try container.encode(oldestPrice, forKey: .oldestPrice)
        try container.encode(currentPrice, forKey: .currentPrice)
        try container.encode(lastStoreID, forKey: .lastStoreID)
        try container.encode(defaultStoreID, forKey: .defaultStoreID)
        try container.encode(nextDueDate, forKey: .nextDueDate)
        try container.encode(locationID, forKey: .location)
        try container.encode(averageShelfLifeDays, forKey: .averageShelfLifeDays)
        try container.encode(spoilRatePercent, forKey: .spoilRatePercent)
        try container.encode(isAggregatedAmount, forKey: .isAggregatedAmount)
        try container.encode(hasChilds, forKey: .hasChilds)
        try container.encode(defaultConsumeLocationID, forKey: .defaultConsumeLocation)
        try container.encode(quConversionFactorPurchaseToStock, forKey: .quConversionFactorPurchaseToStock)
        try container.encode(quConversionFactorPriceToStock, forKey: .quConversionFactorPriceToStock)
    }
}
