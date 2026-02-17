//
//  ReminderStore.swift
//  Grocy Mobile
//
//  Manages iOS Reminders integration, supporting per-store reminder lists.
//

import EventKit
import Foundation
import Observation
import SwiftUI

enum ReminderSyncError: LocalizedError {
    case accessDenied
    case accessRestricted
    case failedReadingCalendarItem
    case failedReadingReminders
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "The app doesn't have permission to read reminders."
        case .accessRestricted:
            return "This device doesn't allow access to reminders."
        case .failedReadingCalendarItem:
            return "Failed to read a calendar item."
        case .failedReadingReminders:
            return "Failed to read reminders."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

// Grocy shopping item identifier stored in reminder notes for tracking
private let grocyReminderTag = "grocy-item-id:"

@Observable
final class ReminderStore {
    static let shared = ReminderStore()

    private let ekStore = EKEventStore()

    // Authorization status
    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    // MARK: - Access

    func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .fullAccess:
            return
        case .restricted:
            throw ReminderSyncError.accessRestricted
        case .notDetermined, .denied, .writeOnly:
            let granted = try await ekStore.requestFullAccessToReminders()
            if !granted {
                throw ReminderSyncError.accessDenied
            }
        @unknown default:
            throw ReminderSyncError.unknown
        }
    }

    // MARK: - Available Lists

    /// Returns all reminder lists (calendars) available on the device
    func availableLists() -> [EKCalendar] {
        return ekStore.calendars(for: .reminder).sorted { $0.title < $1.title }
    }

    /// Find a calendar by its title
    func calendar(named name: String) -> EKCalendar? {
        ekStore.calendars(for: .reminder).first { $0.title == name }
    }

    // MARK: - Sync Shopping Items to a Specific List

    /// Syncs shopping list items for a specific store to the named reminder list.
    /// - Parameters:
    ///   - items: Product names to sync (not-done items)
    ///   - doneItems: Product names of completed items
    ///   - listName: The iOS Reminders list name to sync to
    ///   - storeID: Grocy store ID (used as a namespace in reminder notes)
    func syncItems(
        notDone: [(id: Int, productID: Int, name: String)],
        done: [(id: Int, productID: Int, name: String)],
        to listName: String,
        storeID: Int
    ) throws {
        guard hasAccess else { throw ReminderSyncError.accessDenied }
        guard let calendar = calendar(named: listName) else {
            GrocyLogger.warning("ReminderStore: No list named '\(listName)' found, skipping sync")
            return
        }

        // Fetch all existing reminders in this list
        let existingReminders = fetchRemindersSync(in: calendar)

        // Build a map of grocy item ID → existing reminder
        var existingByItemID: [Int: EKReminder] = [:]
        for reminder in existingReminders {
            if let itemID = extractGrocyItemID(from: reminder.notes) {
                existingByItemID[itemID] = reminder
            }
        }

        let allItems = notDone + done
        let allItemIDs = Set(allItems.map { $0.id })

        // Remove reminders for items no longer on the shopping list
        for (itemID, reminder) in existingByItemID {
            if !allItemIDs.contains(itemID) {
                try ekStore.remove(reminder, commit: false)
                GrocyLogger.info("ReminderStore: Removed reminder for item \(itemID)")
            }
        }

        // Add or update not-done items
        for item in notDone {
            if let existing = existingByItemID[item.id] {
                // Update if title changed
                if existing.title != item.name {
                    existing.title = item.name
                    try ekStore.save(existing, commit: false)
                }
                // Uncheck if it was marked done
                if existing.isCompleted {
                    existing.isCompleted = false
                    try ekStore.save(existing, commit: false)
                }
            } else {
                // Create new reminder
                let reminder = EKReminder(eventStore: ekStore)
                reminder.title = item.name
                reminder.notes = "[grocy:\(item.productID)]\n\(grocyReminderTag)\(item.id)"
                reminder.calendar = calendar
                reminder.isCompleted = false
                try ekStore.save(reminder, commit: false)
                GrocyLogger.info("ReminderStore: Added reminder '\(item.name)' to '\(listName)'")
            }
        }

        // Mark done items as completed (don't delete, let user clear)
        for item in done {
            if let existing = existingByItemID[item.id], !existing.isCompleted {
                existing.isCompleted = true
                try ekStore.save(existing, commit: false)
            }
        }

        // Commit all changes in one batch
        try ekStore.commit()
        GrocyLogger.info("ReminderStore: Synced \(notDone.count) active, \(done.count) done items to '\(listName)'")
    }

    /// Remove all Grocy-managed reminders from a list (used when unmapping a store)
    func clearGrocyReminders(from listName: String) throws {
        guard hasAccess else { return }
        guard let calendar = calendar(named: listName) else { return }

        let reminders = fetchRemindersSync(in: calendar)
        for reminder in reminders {
            if reminder.notes?.contains(grocyReminderTag) == true {
                try ekStore.remove(reminder, commit: false)
            }
        }
        try ekStore.commit()
        GrocyLogger.info("ReminderStore: Cleared all Grocy reminders from '\(listName)'")
    }

    // MARK: - Private Helpers

    private func fetchRemindersSync(in calendar: EKCalendar) -> [EKReminder] {
        var result: [EKReminder] = []
        let semaphore = DispatchSemaphore(value: 0)
        let predicate = ekStore.predicateForReminders(in: [calendar])
        ekStore.fetchReminders(matching: predicate) { reminders in
            result = reminders ?? []
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    private func extractGrocyItemID(from notes: String?) -> Int? {
        guard let notes = notes,
              let range = notes.range(of: grocyReminderTag) else { return nil }
        let remainder = String(notes[range.upperBound...])
        // Only parse the leading integer, ignoring any trailing annotation like " (Product Name)"
        let idString = remainder.prefix(while: { $0.isNumber })
        return Int(idString)
    }
}
