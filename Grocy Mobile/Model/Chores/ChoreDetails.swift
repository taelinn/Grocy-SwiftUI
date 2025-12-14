//
//  ChoreDetailsModel.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 13.12.25.
//

import Foundation
import SwiftData

@Model
class ChoreDetails: Codable, Equatable, Identifiable {
    @Attribute(.unique) var id: UUID
    var choreID: Int?
    var lastTracked: Date?
    var trackedCount: Int
    var lastDoneByUserID: Int?
    var nextEstimatedExecutionTime: Date?
    var nextExecutionAssignedUserID: Int?
    var averageExecutionFrequencyHours: Double?

    @Transient
    var chore: MDChore? {
        fetchChore(id: choreID)
    }

    @Transient
    var lastDoneBy: GrocyUser? {
        fetchUser(id: lastDoneByUserID)
    }

    @Transient
    var nextExecutionAssignedUser: GrocyUser? {
        fetchUser(id: nextExecutionAssignedUserID)
    }

    private func fetchChore(id: Int?) -> MDChore? {
        guard let id = id, let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<MDChore>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchUser(id: Int?) -> GrocyUser? {
        guard let id = id, let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<GrocyUser>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    enum CodingKeys: String, CodingKey {
        case chore
        case lastTracked = "last_tracked"
        case trackedCount = "tracked_count"
        case lastDoneBy = "last_done_by"
        case nextEstimatedExecutionTime = "next_estimated_execution_time"
        case nextExecutionAssignedUser = "next_execution_assigned_user"
        case averageExecutionFrequencyHours = "average_execution_frequency_hours"
    }

    enum NestedIDKeys: String, CodingKey {
        case id
    }

    required init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.id = UUID()
            self.trackedCount = try container.decodeFlexibleInt(forKey: .trackedCount)
            self.lastTracked = getDateFromString(try container.decodeIfPresent(String.self, forKey: .lastTracked))

            // Extract chore ID from nested object
            if let choreContainer = try? container.nestedContainer(keyedBy: NestedIDKeys.self, forKey: .chore) {
                self.choreID = try? choreContainer.decodeFlexibleInt(forKey: .id)
            } else {
                self.choreID = nil
            }

            // Extract user IDs from nested objects
            if let userContainer = try? container.nestedContainer(keyedBy: NestedIDKeys.self, forKey: .lastDoneBy) {
                self.lastDoneByUserID = try? userContainer.decodeFlexibleInt(forKey: .id)
            } else {
                self.lastDoneByUserID = nil
            }

            self.nextEstimatedExecutionTime = getDateFromString(try container.decodeIfPresent(String.self, forKey: .nextEstimatedExecutionTime))

            // Extract user IDs from nested objects
            if let userContainer = try? container.nestedContainer(keyedBy: NestedIDKeys.self, forKey: .nextExecutionAssignedUser) {
                self.nextExecutionAssignedUserID = try? userContainer.decodeFlexibleInt(forKey: .id)
            } else {
                self.nextExecutionAssignedUserID = nil
            }

            self.averageExecutionFrequencyHours = try container.decodeFlexibleDoubleIfPresent(forKey: .averageExecutionFrequencyHours)
        } catch {
            throw APIError.decodingError(error: error)
        }
    }

    init(
        choreID: Int?,
        lastTracked: Date? = nil,
        trackedCount: Int = 0,
        lastDoneByUserID: Int? = nil,
        nextEstimatedExecutionTime: Date? = nil,
        nextExecutionAssignedUserID: Int? = nil,
        averageExecutionFrequencyHours: Double? = nil
    ) {
        self.id = UUID()
        self.choreID = choreID
        self.lastTracked = lastTracked
        self.trackedCount = trackedCount
        self.lastDoneByUserID = lastDoneByUserID
        self.nextEstimatedExecutionTime = nextEstimatedExecutionTime
        self.nextExecutionAssignedUserID = nextExecutionAssignedUserID
        self.averageExecutionFrequencyHours = averageExecutionFrequencyHours
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(choreID, forKey: .chore)
        try container.encode(lastTracked, forKey: .lastTracked)
        try container.encode(trackedCount, forKey: .trackedCount)
        try container.encode(lastDoneByUserID, forKey: .lastDoneBy)
        try container.encode(nextEstimatedExecutionTime, forKey: .nextEstimatedExecutionTime)
        try container.encode(nextExecutionAssignedUserID, forKey: .nextExecutionAssignedUser)
        try container.encode(averageExecutionFrequencyHours, forKey: .averageExecutionFrequencyHours)
    }
}
