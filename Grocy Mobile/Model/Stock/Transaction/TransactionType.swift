//
//  TransactionType.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 20.11.20.
//

import Foundation
import SwiftUI

enum TransactionType: String, Codable, CaseIterable {
    case consume = "consume"
    case inventoryCorrection = "inventory-correction"
    case productOpened = "product-opened"
    case purchase = "purchase"
    case selfProduction = "self-production"
    case stockEditNew = "stock-edit-new"
    case stockEditOld = "stock-edit-old"
    case transferFrom = "transfer_from"
    case transferTo = "transfer_to"

    var localizedName: LocalizedStringKey {
        switch self {
        case .consume:
            return LocalizedStringKey("Consume")
        case .inventoryCorrection:
            return LocalizedStringKey("Inventory correction")
        case .productOpened:
            return LocalizedStringKey("Product opened")
        case .purchase:
            return LocalizedStringKey("Purchase")
        case .selfProduction:
            return LocalizedStringKey("Self-production")
        case .stockEditNew:
            return LocalizedStringKey("Stock entry edited (new values)")
        case .stockEditOld:
            return LocalizedStringKey("Stock entry edited (old values)")
        case .transferFrom:
            return LocalizedStringKey("Transfer From")
        case .transferTo:
            return LocalizedStringKey("Transfer To")
        }
    }
}
