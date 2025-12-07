//
//  Untitled.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 07.12.25.
//

import Foundation

// MARK: - RecipeNestingElement
struct RecipeNesting: Codable {
    let id: Int
    let recipeID: Int
    let includesRecipeID: Int
    let servings: Int
    let rowCreatedTimestamp: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipeID = "recipe_id"
        case includesRecipeID = "includes_recipe_id"
        case rowCreatedTimestamp = "row_created_timestamp"
        case servings
    }
}

typealias RecipesNesting = [RecipeNesting]

