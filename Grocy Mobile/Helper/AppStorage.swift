//
//  AppStorage.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 24.11.25.
//

import Foundation

extension UUID: @retroactive RawRepresentable {
    public var rawValue: String {
        self.uuidString
    }
    
    public typealias RawValue = String
    
    public init?(rawValue: RawValue) {
        self.init(uuidString: rawValue)
    }
}

// MARK: - Store Reminder Mappings
// Stores a mapping of Grocy store ID → iOS Reminders list name
// Stored as JSON in UserDefaults: key "storeReminderMappings"
// Format: { "42": "Costco", "7": "SA Shop" }

enum StoreReminderMappings {
    static let userDefaultsKey = "storeReminderMappings"
    static let syncEnabledKey = "reminderSyncEnabled"
    /// Reminder list name for items with no store assigned (or store not mapped)
    static let defaultListKey = "reminderDefaultList"

    static func load() -> [Int: String] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: dict.compactMap { key, value in
            guard let intKey = Int(key) else { return nil }
            return (intKey, value)
        })
    }

    static func save(_ mappings: [Int: String]) {
        let dict = Dictionary(uniqueKeysWithValues: mappings.map { ("\($0.key)", $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    static func listName(for storeID: Int) -> String? {
        return load()[storeID]
    }
}
