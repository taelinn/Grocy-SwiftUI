//
//  RecipeModel.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 02.12.22.
//

import Foundation
import SwiftData

@Model
class Recipe: Codable, Identifiable {
    @Attribute(.unique) var id: Int
    var name: String
    var recipeDescription: String?
    var pictureFileName: String?
    var baseServings: Int
    var desiredServings: Int?
    var notCheckShoppinglist: Bool?
    var type: RecipeType
    var productID: Int?
    var rowCreatedTimestamp: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case recipeDescription = "description"
        case pictureFileName = "picture_file_name"
        case baseServings = "base_servings"
        case desiredServings = "desired_servings"
        case notCheckShoppinglist = "not_check_shoppinglist"
        case type
        case productID = "product_id"
        case rowCreatedTimestamp = "row_created_timestamp"
    }

    required init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decodeFlexibleInt(forKey: .id)
            self.name = try container.decode(String.self, forKey: .name)
            self.recipeDescription = try? container.decodeIfPresent(String.self, forKey: .recipeDescription) ?? nil
            self.pictureFileName = try? container.decodeIfPresent(String.self, forKey: .pictureFileName) ?? nil
            self.baseServings = try container.decodeFlexibleInt(forKey: .baseServings)
            self.desiredServings = try container.decodeFlexibleIntIfPresent(forKey: .desiredServings)
            self.notCheckShoppinglist = try container.decodeFlexibleBoolIfPresent(forKey: .notCheckShoppinglist)
            self.type = try container.decode(RecipeType.self, forKey: .type)
            self.productID = try container.decodeFlexibleIntIfPresent(forKey: .productID)
            self.rowCreatedTimestamp = try container.decode(String.self, forKey: .rowCreatedTimestamp)
        } catch {
            throw APIError.decodingError(error: error)
        }
    }

    init(
        id: Int = -1,
        name: String = "",
        recipeDescription: String? = nil,
        pictureFileName: String? = nil,
        baseServings: Int = 0,
        desiredServings: Int? = nil,
        notCheckShoppinglist: Bool? = nil,
        type: RecipeType = .normal,
        productID: Int? = nil,
        rowCreatedTimestamp: String? = nil
    ) {
        self.id = id
        self.name = name
        self.recipeDescription = recipeDescription
        self.pictureFileName = pictureFileName
        self.baseServings = baseServings
        self.desiredServings = desiredServings
        self.notCheckShoppinglist = notCheckShoppinglist
        self.type = type
        self.productID = productID
        self.rowCreatedTimestamp = rowCreatedTimestamp ?? Date().iso8601withFractionalSeconds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(pictureFileName, forKey: .pictureFileName)
        try container.encode(baseServings, forKey: .baseServings)
        try container.encode(desiredServings, forKey: .desiredServings)
        try container.encode(notCheckShoppinglist, forKey: .notCheckShoppinglist)
        try container.encode(type, forKey: .type)
        try container.encode(productID, forKey: .productID)
        try container.encode(rowCreatedTimestamp, forKey: .rowCreatedTimestamp)
    }
}

typealias Recipes = [Recipe]
