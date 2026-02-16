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
    var productID: Int = 0
    var sortOrder: Int = 0
    var grocyServerURL: String = ""
    var dateAdded: Date = Date()
    
    // Compound identifier: productID + serverURL (uniqueness enforced in application logic)
    var id: String = ""
    
    init(productID: Int, sortOrder: Int = 0, grocyServerURL: String) {
        self.productID = productID
        self.sortOrder = sortOrder
        self.grocyServerURL = grocyServerURL
        self.dateAdded = Date()
        self.id = "\(grocyServerURL)_\(productID)"
    }
}
