//
//  SwiftDataActor.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 29.11.25.
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataActor {
    func getObjectAndSaveSwiftData<T: Codable & Equatable & Identifiable & PersistentModel>(
        object: ObjectEntities,
        grocyApi: GrocyAPI
    ) async throws -> [T] {
        let incomingObjects: [T] = try await grocyApi.getObject(object: object)

        // Fetch existing objects within the isolated context
        let fetchDescriptor = FetchDescriptor<T>(sortBy: [SortDescriptor(\T.id)])
        let existingObjects: [T]

        do {
            existingObjects = try modelContext.fetch(fetchDescriptor)
        } catch {
            // If fetch fails, clear and insert the new objects in a clean state
            try clearAndInsertObjects(incomingObjects)
            return incomingObjects
        }

        // Perform synchronization within a single transaction-like context
        try synchronizeObjects(existing: existingObjects, incoming: incomingObjects)

        // Ensure all changes are persisted before returning
        try await Task.sleep(nanoseconds: 0)  // Yield to allow SwiftData to finalize changes

        return incomingObjects
    }

    /// Generic sync for collection models with identity-based deduplication.
    /// Works with any Identifiable, PersistentModel collection.
    func syncPersistentCollection<T: Identifiable & PersistentModel>(
        _ modelType: T.Type,
        with incoming: [T]
    ) async throws {
        do {
            let fetchDescriptor = FetchDescriptor<T>()
            let existing = try modelContext.fetch(fetchDescriptor)

            // Delete removed items
            let incomingIds = Set(incoming.map { $0.id })
            for item in existing where !incomingIds.contains(item.id) {
                modelContext.delete(item)
            }

            // Insert new items (skip existing)
            let existingIds = Set(existing.map { $0.id })
            for item in incoming where !existingIds.contains(item.id) {
                modelContext.insert(item)
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Generic sync for singleton models (one instance exists).
    /// Replaces all with the new value.
    func syncSingletonModel<T: PersistentModel>(
        _ modelType: T.Type,
        with value: T?
    ) async throws {
        do {
            try modelContext.delete(model: modelType)
            if let value = value {
                modelContext.insert(value)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Generic sync for array models (complete replacement).
    /// Used when relationship tracking requires clean state.
    func syncArrayModel<T: PersistentModel>(
        _ modelType: T.Type,
        with incoming: [T]
    ) async throws {
        do {
            try modelContext.delete(model: modelType)
            for item in incoming {
                modelContext.insert(item)
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Specialized sync for StockElement with product relationship resolution.
    /// Fetches MDProducts from modelContext to establish relationships.
    func syncStockElements(
        _ stockElements: [StockElement]
    ) async throws {
        do {
            let fetchDescriptor = FetchDescriptor<StockElement>()
            let existing = try modelContext.fetch(fetchDescriptor)

            // Delete removed items
            let incomingIds = Set(stockElements.map { $0.id })
            for item in existing where !incomingIds.contains(item.id) {
                modelContext.delete(item)
            }

            // Fetch all products for relationship resolution
            let productDescriptor = FetchDescriptor<MDProduct>()
            let productsById = Dictionary(
                uniqueKeysWithValues: try modelContext.fetch(productDescriptor).map { ($0.id, $0) }
            )

            // Insert/link new items
            let existingIds = Set(existing.map { $0.id })
            for element in stockElements where !existingIds.contains(element.id) {
                // Link to existing product if available
                if let product = productsById[element.productID] {
                    element.product = product
                }
                modelContext.insert(element)
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Clears existing objects and inserts new ones atomically.
    private func clearAndInsertObjects<T: PersistentModel>(_ newObjects: [T]) throws {
        let fetchDescriptor = FetchDescriptor<T>()
        let existingObjects = try modelContext.fetch(fetchDescriptor)

        // Delete all existing objects
        for object in existingObjects {
            modelContext.delete(object)
        }

        // Insert new objects
        for newObject in newObjects {
            modelContext.insert(newObject)
        }

        // Save with error handling
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Synchronizes existing objects with incoming data, handling inserts, updates, and deletes.
    /// All operations are performed atomically within the model context.
    private func synchronizeObjects<T: Codable & Equatable & Identifiable & PersistentModel>(
        existing: [T],
        incoming: [T]
    ) throws {
        // Build lookup dictionaries for efficient comparison
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingById = Dictionary(uniqueKeysWithValues: incoming.map { ($0.id, $0) })

        // Track which objects have been processed to avoid double-deletion
        var processedIds = Set<T.ID>()

        // Phase 1: Handle deletions of objects no longer in incoming data
        for existingObject in existing {
            if incomingById[existingObject.id] == nil {
                modelContext.delete(existingObject)
                processedIds.insert(existingObject.id)
            }
        }

        // Phase 2: Handle insertions and updates
        for newObject in incoming {
            if let existingObject = existingById[newObject.id] {
                // Check if object needs updating
                if existingObject != newObject {
                    // For SwiftData, update by deleting and re-inserting to ensure consistency
                    modelContext.delete(existingObject)
                    modelContext.insert(newObject)
                }
            } else {
                // New object, insert it
                modelContext.insert(newObject)
            }
            processedIds.insert(newObject.id)
        }

        // Phase 3: Save all changes atomically
        do {
            try modelContext.save()
        } catch {
            // Rollback on any error to maintain consistency
            modelContext.rollback()
            throw error
        }
    }
}
