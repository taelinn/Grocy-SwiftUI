//
//  Grocy_Widget.swift
//  Grocy Widget
//
//  Created by Georg Meißner on 06.12.25.
//

import SwiftData
import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    let sharedModelContainer = createSharedModelContainer()

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), modelContainer: nil, volatileStock: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let volatileStock = await loadVolatileStock()
        return SimpleEntry(date: Date(), configuration: configuration, modelContainer: sharedModelContainer, volatileStock: volatileStock)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let volatileStock = await loadVolatileStock()
        let entry = SimpleEntry(date: Date(), configuration: configuration, modelContainer: sharedModelContainer, volatileStock: volatileStock)
        
        // Request update every 15 minutes to keep data fresh
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func loadVolatileStock() async -> VolatileStock? {
        guard let modelContainer = sharedModelContainer else { return nil }
        
        let context = ModelContext(modelContainer)
        do {
            let fetchDescriptor = FetchDescriptor<VolatileStock>()
            let results = try context.fetch(fetchDescriptor)
            return results.first
        } catch {
            print("Failed to load VolatileStock: \(error)")
            return nil
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let modelContainer: ModelContainer?
    let volatileStock: VolatileStock?
}

struct Grocy_WidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if let modelContainer = entry.modelContainer {
            StockWidgetView(entry: entry)
                .modelContainer(modelContainer)
        } else {
            VStack {
                Image(systemName: "exclamationmark.circle")
                    .font(.title)
                Text("Unable to load data")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct Grocy_Widget: Widget {
    let kind: String = "Grocy_Widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            Grocy_WidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
