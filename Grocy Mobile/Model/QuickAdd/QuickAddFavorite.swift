//
//  QuickAddFavorite.swift
//  Grocy Mobile
//
//  Model for Quick Add UI preferences (local storage only)
//  Favorite status and note requirement are stored on server via UserFields
//

import Foundation
import SwiftData

@Model
final class QuickAddFavorite {
    @Attribute(.unique) var productID: Int
    var sortOrder: Int
    var grocyServerURL: String
    var dateAdded: Date
    
    init(productID: Int, sortOrder: Int = 0, grocyServerURL: String) {
        self.productID = productID
        self.sortOrder = sortOrder
        self.grocyServerURL = grocyServerURL
        self.dateAdded = Date()
    }
}
