//
//  BarcodeBuddyWidget.swift
//  Grocy Widget
//
//  BarcodeBuddy unresolved barcodes widget
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct BBProvider: AppIntentTimelineProvider {
    let sharedModelContainer = createSharedModelContainer()

    func placeholder(in context: Context) -> BBEntry {
        BBEntry(date: Date(), configuration: BBConfigurationAppIntent(), newBarcodesCount: 0, unknownBarcodesCount: 0)
    }

    func snapshot(for configuration: BBConfigurationAppIntent, in context: Context) async -> BBEntry {
        let counts = await loadBarcodeBuddyCounts()
        return BBEntry(date: Date(), configuration: configuration, newBarcodesCount: counts.new, unknownBarcodesCount: counts.unknown)
    }

    func timeline(for configuration: BBConfigurationAppIntent, in context: Context) async -> Timeline<BBEntry> {
        let counts = await loadBarcodeBuddyCounts()
        let entry = BBEntry(date: Date(), configuration: configuration, newBarcodesCount: counts.new, unknownBarcodesCount: counts.unknown)
        
        // Request update every 15 minutes to keep data fresh
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func loadBarcodeBuddyCounts() async -> (new: Int, unknown: Int) {
        guard let modelContainer = sharedModelContainer else { return (0, 0) }
        
        let context = ModelContext(modelContainer)
        do {
            // Fetch cached counts from SwiftData
            let descriptor = FetchDescriptor<BarcodeBuddyCache>()
            let results = try context.fetch(descriptor)
            if let cache = results.first {
                return (cache.newBarcodesCount, cache.unknownBarcodesCount)
            }
            return (0, 0)
        } catch {
            print("Failed to load BarcodeBuddy counts: \(error)")
            return (0, 0)
        }
    }
}

struct BBEntry: TimelineEntry {
    let date: Date
    let configuration: BBConfigurationAppIntent
    let newBarcodesCount: Int
    let unknownBarcodesCount: Int
    
    var totalCount: Int {
        newBarcodesCount + unknownBarcodesCount
    }
}

struct BBConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "BarcodeBuddy Widget Configuration"
    static var description: IntentDescription = "Shows unresolved barcodes from BarcodeBuddy"
}

struct BarcodeBuddyWidgetEntryView: View {
    var entry: BBProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            mediumWidget // Large not needed for this widget
        }
    }
    
    private var smallWidget: some View {
        VStack(spacing: 4) {
            // Title
            HStack {
                Image(systemName: "barcode.viewfinder")
                    .font(.caption)
                Text("Barcodes")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            Spacer()
            
            // New Barcodes Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(entry.newBarcodesCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.green)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 12)
            
            Divider()
                .padding(.horizontal, 8)
            
            // Unknown Barcodes Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unknown")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(entry.unknownBarcodesCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "grocy://barcodebuddy"))
    }
    
    private var mediumWidget: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .frame(width: 50)
            
            // New Barcodes
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("New")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("\(entry.newBarcodesCount)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Unknown Barcodes
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text("\(entry.unknownBarcodesCount)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "grocy://barcodebuddy"))
    }
}

struct BarcodeBuddyWidget: Widget {
    let kind: String = "BarcodeBuddyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: BBConfigurationAppIntent.self, provider: BBProvider()) { entry in
            BarcodeBuddyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("BarcodeBuddy")
        .description("Shows unresolved barcodes that need your attention")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) {
    BarcodeBuddyWidget()
} timeline: {
    BBEntry(date: .now, configuration: BBConfigurationAppIntent(), newBarcodesCount: 3, unknownBarcodesCount: 5)
    BBEntry(date: .now, configuration: BBConfigurationAppIntent(), newBarcodesCount: 0, unknownBarcodesCount: 0)
}

#Preview("Medium", as: .systemMedium) {
    BarcodeBuddyWidget()
} timeline: {
    BBEntry(date: .now, configuration: BBConfigurationAppIntent(), newBarcodesCount: 8, unknownBarcodesCount: 4)
    BBEntry(date: .now, configuration: BBConfigurationAppIntent(), newBarcodesCount: 0, unknownBarcodesCount: 0)
}
