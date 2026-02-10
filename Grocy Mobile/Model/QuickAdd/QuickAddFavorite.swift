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
    var productID: Int
    var sortOrder: Int
    var grocyServerURL: String
    var dateAdded: Date
    
    // Compound unique identifier: productID + serverURL
    @Attribute(.unique) var id: String
    
    init(productID: Int, sortOrder: Int = 0, grocyServerURL: String) {
        self.productID = productID
        self.sortOrder = sortOrder
        self.grocyServerURL = grocyServerURL
        self.dateAdded = Date()
        self.id = "\(grocyServerURL)_\(productID)"
    }
}
