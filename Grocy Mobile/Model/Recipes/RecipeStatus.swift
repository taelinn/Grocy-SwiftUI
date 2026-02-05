//
//  RecipeStatus.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 05.02.26.
//

import Foundation
import SwiftUI

enum RecipeStatus: LocalizedStringKey {
    case all = "All"
    case enoughInStock = "Enough in stock"
    case alreadyOnShoppingList = "Not enough in stock, but already on the shopping list"
    case notEnoughInStock = "Not enough in stock"

    func getIconName() -> String {
        switch self {
        case .enoughInStock:
            return "checkmark.circle.fill"
        case .alreadyOnShoppingList:
            return "exclamationmark.circle.fill"
        case .notEnoughInStock:
            return "xmark.circle.fill"
        default:
            return "tag.fill"
        }
    }
}
