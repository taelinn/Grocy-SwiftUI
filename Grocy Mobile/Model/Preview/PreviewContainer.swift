//
//  PreviewContainer.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 19.11.25.
//

import Foundation
import SwiftData
import SwiftUI

struct PreviewDataTrait: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        return PreviewContainer.shared
    }
    
    let grocyVM = GrocyViewModel(modelContext: PreviewContainer.shared.mainContext, profileModelContext: PreviewContainer.shared.mainContext)

    func body(content: Content, context: ModelContainer) -> some View {
        content
            .environment(grocyVM)
            .modelContainer(PreviewContainer.shared)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var previewData: Self = .modifier(PreviewDataTrait())
}

@MainActor
struct PreviewContainer {
    /// Default folder name for loading JSON data files
    static let defaultDataFolder = "TestData"

    static let shared: ModelContainer = {
        do {
            let schema = Schema([
                MDLocation.self,
                MDProductGroup.self,
                MDProduct.self,
                MDQuantityUnitConversion.self,
                MDQuantityUnit.self,
                ShoppingListItem.self,
                ShoppingListDescription.self,
                MDStore.self,
                StockElement.self,
                StockJournalEntry.self,
                StockElement.self,
                VolatileStock.self,
                GrocyUser.self,
            ])

            let container = try ModelContainer(
                for: schema,
                configurations: .init(isStoredInMemoryOnly: true, cloudKitDatabase: .none),
            )

            seedData(container: container)

            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()

    private static func seedData(container: ModelContainer) {
        let context = container.mainContext

        // Objects
        loadAndInsert(modelType: MDLocation.self, filename: "objects__locations.json", into: context)
        loadAndInsert(modelType: MDProductGroup.self, filename: "objects__product_groups.json", into: context)
        loadAndInsert(modelType: MDProduct.self, filename: "objects__products.json", into: context)
        loadAndInsert(modelType: MDQuantityUnitConversion.self, filename: "objects__quantity_unit_conversions.json", into: context)
        loadAndInsert(modelType: MDQuantityUnit.self, filename: "objects__quantity_units.json", into: context)
        loadAndInsert(modelType: ShoppingListItem.self, filename: "objects__shopping_list.json", into: context)
        loadAndInsert(modelType: ShoppingListDescription.self, filename: "objects__shopping_lists.json", into: context)
        loadAndInsert(modelType: MDStore.self, filename: "objects__shopping_locations.json", into: context)
        loadAndInsert(modelType: StockEntry.self, filename: "objects__stock.json", into: context)
        loadAndInsert(modelType: StockJournalEntry.self, filename: "objects__stock_log.json", into: context)
        
        // Other
        loadAndInsert(modelType: StockElement.self, filename: "stock.json", into: context)
        loadAndInsert(modelType: VolatileStock.self, filename: "stock__volatile.json", into: context, singleElement: true)
        loadAndInsert(modelType: GrocyUser.self, filename: "users.json", into: context)

        try? context.save()
    }

    private static func loadAndInsert<T>(
        modelType: T.Type,
        filename: String,
        into context: ModelContext,
        singleElement: Bool = false
    ) where T: PersistentModel & Decodable {
        let fileManager = FileManager.default
        let currentFileURL = URL(fileURLWithPath: #file)
        let currentDirectory = currentFileURL.deletingLastPathComponent()
        let dataFolderURL = currentDirectory.appendingPathComponent(defaultDataFolder)
        let fileURL = dataFolderURL.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("⚠️ Could not find \(filename) in \(defaultDataFolder)/")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            
            if singleElement {
                let item = try decoder.decode(T.self, from: data)
                context.insert(item)
            } else {
                let items = try decoder.decode([T].self, from: data)
                
                for item in items {
                    context.insert(item)
                }
            }
        } catch {
            print("⚠️ Failed to decode \(filename): \(error)")
        }
    }
}
