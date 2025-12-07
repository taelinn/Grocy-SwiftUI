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
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), modelContainer: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, modelContainer: sharedModelContainer)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(date: Date(), configuration: configuration, modelContainer: sharedModelContainer)
        return Timeline(entries: [entry], policy: .never)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let modelContainer: ModelContainer?
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
