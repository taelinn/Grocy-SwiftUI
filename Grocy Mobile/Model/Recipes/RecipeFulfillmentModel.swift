//
//  RecipeFulfillmentModel.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 09.12.22.
//

import Foundation
import SwiftData

@Model
class RecipeFulfilment: Codable, Identifiable {
    @Attribute(.unique) var id: UUID
    var equalID: Int
    var recipeID: Int
    var needFulfilled: Int?
    var needFulfilledWithShoppingList: Int?
    var missingProductsCount: Int?
    var costs: Double?
    var costsPerServing: Double?
    var calories: Double?
    var dueScore: Int?
    var productNamesCommaSeparated: String?

    enum CodingKeys: String, CodingKey {
        case equalID = "id"
        case recipeID = "recipe_id"
        case needFulfilled = "need_fulfilled"
        case needFulfilledWithShoppingList = "need_fulfilled_with_shopping_list"
        case missingProductsCount = "missing_products_count"
        case costs
        case costsPerServing = "costs_per_serving"
        case calories
        case dueScore = "due_score"
        case productNamesCommaSeparated = "product_names_comma_separated"
    }

    required init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            do { self.equalID = try container.decode(Int.self, forKey: .equalID) } catch { self.equalID = Int(try container.decode(String.self, forKey: .equalID))! }
            do { self.recipeID = try container.decode(Int.self, forKey: .recipeID) } catch { self.recipeID = Int(try container.decode(String.self, forKey: .recipeID))! }
            do { self.needFulfilled = try container.decodeIfPresent(Int.self, forKey: .needFulfilled) } catch { self.needFulfilled = try? Int(container.decodeIfPresent(String.self, forKey: .needFulfilled) ?? "") }
            do { self.needFulfilledWithShoppingList = try container.decodeIfPresent(Int.self, forKey: .needFulfilledWithShoppingList) } catch {
                self.needFulfilledWithShoppingList = try? Int(container.decodeIfPresent(String.self, forKey: .needFulfilledWithShoppingList) ?? "")
            }
            do { self.missingProductsCount = try container.decodeIfPresent(Int.self, forKey: .missingProductsCount) } catch {
                self.missingProductsCount = try? Int(container.decodeIfPresent(String.self, forKey: .missingProductsCount) ?? "")
            }
            do { self.costs = try container.decodeIfPresent(Double.self, forKey: .costs) } catch { self.costs = try? Double(container.decodeIfPresent(String.self, forKey: .costs) ?? "") }
            do { self.costsPerServing = try container.decodeIfPresent(Double.self, forKey: .costsPerServing) } catch { self.costsPerServing = try? Double(container.decodeIfPresent(String.self, forKey: .costsPerServing) ?? "") }
            do { self.calories = try container.decodeIfPresent(Double.self, forKey: .calories) } catch { self.calories = try? Double(container.decodeIfPresent(String.self, forKey: .calories) ?? "") }
            do { self.dueScore = try container.decodeIfPresent(Int.self, forKey: .dueScore) } catch { self.dueScore = try? Int(container.decodeIfPresent(String.self, forKey: .dueScore) ?? "") }
            self.productNamesCommaSeparated = try? container.decodeIfPresent(String.self, forKey: .productNamesCommaSeparated) ?? nil
        } catch {
            throw APIError.decodingError(error: error)
        }
    }

    init(
        id: Int = -1,
        recipeID: Int,
        needFulfilled: Int? = 0,
        needFulfilledWithShoppingList: Int? = 0,
        missingProductsCount: Int? = nil,
        costs: Double? = nil,
        costsPerServing: Double? = nil,
        calories: Double? = nil,
        dueScore: Int? = nil,
        productNamesCommaSeparated: String? = nil,
    ) {
        self.id = UUID()
        self.equalID = id
        self.recipeID = recipeID
        self.needFulfilled = needFulfilled
        self.needFulfilledWithShoppingList = needFulfilledWithShoppingList
        self.missingProductsCount = missingProductsCount
        self.costs = costs
        self.costsPerServing = costsPerServing
        self.calories = calories
        self.dueScore = dueScore
        self.productNamesCommaSeparated = productNamesCommaSeparated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .equalID)
        try container.encode(recipeID, forKey: .recipeID)
        try container.encode(needFulfilled, forKey: .needFulfilled)
        try container.encode(needFulfilledWithShoppingList, forKey: .needFulfilledWithShoppingList)
        try container.encode(missingProductsCount, forKey: .missingProductsCount)
        try container.encode(costs, forKey: .costs)
        try container.encode(costsPerServing, forKey: .costsPerServing)
        try container.encode(calories, forKey: .calories)
        try container.encode(dueScore, forKey: .dueScore)
        try container.encode(productNamesCommaSeparated, forKey: .productNamesCommaSeparated)
    }
}

typealias RecipeFulfilments = [RecipeFulfilment]
