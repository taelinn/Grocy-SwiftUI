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
        let fetchDescriptor = FetchDescriptor<T>(sortBy: [SortDescriptor(\T.id)])
        let existingObjects = try modelContext.fetch(fetchDescriptor)

        // Process any pending changes before proceeding
        modelContext.processPendingChanges()

        // Build lookup dictionaries
        let existingById = Dictionary(uniqueKeysWithValues: existingObjects.map { ($0.id, $0) })
        let incomingById = Dictionary(uniqueKeysWithValues: incomingObjects.map { ($0.id, $0) })

        // Delete removed objects
        for (id, existingObject) in existingById {
            if incomingById[id] == nil {
                modelContext.delete(existingObject)
            }
        }

        // Insert new or updated objects
        for (id, newObject) in incomingById {
            if let existing = existingById[id] {
                if existing != newObject {
                    modelContext.delete(existing)
                    modelContext.insert(newObject)
                }
            } else {
                modelContext.insert(newObject)
            }
        }

        try modelContext.save()

        // Return PersistentIdentifiers instead of objects
        return incomingObjects
    }
}
