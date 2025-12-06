//
//  WidgetConfiguration.swift
//  Grocy Widget
//

import SwiftData
import SwiftUI

func createSharedModelContainer() -> ModelContainer? {
    let schema = Schema([VolatileStock.self])

    let config = ModelConfiguration(
        schema: schema,
        groupContainer: .identifier("group.georgappdev.Grocy"),
        cloudKitDatabase: .none
    )

    do {
        return try ModelContainer(for: schema, configurations: config)
    } catch {
        print("Failed to create shared model container: \(error)")
        return nil
    }
}
