//
//  WidgetConfiguration.swift
//  Grocy Widget
//

import SwiftData
import SwiftUI

func createSharedModelContainer() -> ModelContainer? {
    let schema = Schema([
        VolatileStock.self,
        BarcodeBuddyCache.self
    ])

    let config = ModelConfiguration(
        schema: schema,
        groupContainer: .identifier("group.com.roadworkstechnology.grocymobile"),
        cloudKitDatabase: .none
    )

    do {
        return try ModelContainer(for: schema, configurations: config)
    } catch {
        print("Failed to create shared model container: \(error)")
        return nil
    }
}
