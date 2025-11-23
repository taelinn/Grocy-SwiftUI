//
//  PreviewContainer.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 19.11.25.
//

import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    do {
        let schema = Schema([
            StockElement.self,
            ShoppingListItem.self,
            ShoppingListDescription.self,
            MDLocation.self,
            MDStore.self,
            MDQuantityUnit.self,
            MDQuantityUnitConversion.self,
            MDProductGroup.self,
            MDProduct.self,
            MDProductBarcode.self,
            StockJournalEntry.self,
            GrocyUser.self,
            StockEntry.self,
            GrocyUserSettings.self,
            StockProductDetails.self,
            StockProduct.self,
            VolatileStock.self,
            Recipe.self,
            StockLocation.self,
            SystemConfig.self,
            RecipePosResolvedElement.self,
            LoginCustomHeader.self,
            ServerProfile.self,
        ])

        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )

        container.mainContext.insert(MDQuantityUnit(id: 1, name: "g", namePlural: "g", active: true, mdQuantityUnitDescription: "Gram", rowCreatedTimestamp: "2025-01-01"))
        container.mainContext.insert(MDQuantityUnit(id: 2, name: "kg", namePlural: "kg", active: true, mdQuantityUnitDescription: "Kilogram", rowCreatedTimestamp: "2025-01-01"))
        container.mainContext.insert(MDQuantityUnit(id: 3, name: "Piece", namePlural: "Pieces", active: true, mdQuantityUnitDescription: "Piece", rowCreatedTimestamp: "2025-01-01"))
        container.mainContext.insert(MDQuantityUnit(id: 4, name: "Package", namePlural: "Packages", active: true, mdQuantityUnitDescription: "Package", rowCreatedTimestamp: "2025-01-01"))
        container.mainContext.insert(
            MDQuantityUnitConversion(
                id: 1,
                fromQuID: 2,
                toQuID: 1,
                factor: 1000,
                productID: nil,
                rowCreatedTimestamp: "2025-01-01"
            )
        )
        container.mainContext.insert(
            MDQuantityUnitConversion(
                id: 2,
                fromQuID: 4,
                toQuID: 3,
                factor: 4,
                productID: nil,
                rowCreatedTimestamp: "2025-01-01"
            )
        )
        container.mainContext.insert(
            MDProduct(
                id: 1,
                name: "Flour",
                mdProductDescription: "All-purpose flour",
                productGroupID: nil,
                active: true,
                locationID: 1,
                storeID: -1,
                quIDPurchase: 1,
                quIDStock: 1,
                quIDConsume: 1,
                quIDPrice: 1,
                minStockAmount: 500,
                defaultDueDays: 365,
                defaultDueDaysAfterOpen: 30,
                defaultDueDaysAfterFreezing: 0,
                defaultDueDaysAfterThawing: 0,
                pictureFileName: nil,
                enableTareWeightHandling: false,
                tareWeight: nil,
                notCheckStockFulfillmentForRecipes: false,
                parentProductID: nil,
                calories: nil,
                cumulateMinStockAmountOfSubProducts: false,
                dueType: 0,
                quickConsumeAmount: nil,
                quickOpenAmount: nil,
                hideOnStockOverview: false,
                defaultStockLabelType: nil,
                shouldNotBeFrozen: false,
                treatOpenedAsOutOfStock: false,
                noOwnStock: false,
                defaultConsumeLocationID: nil,
                moveOnOpen: false,
                autoReprintStockLabel: false,
                rowCreatedTimestamp: "2025-01-01"
            )
        )

        return container
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}()
