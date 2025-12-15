//
//  ChoreModel.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 09.12.25.
//

import Foundation
import SwiftData

@Model
class Chore: Codable, Equatable, Identifiable {
    @Attribute(.unique) var id: Int
    var choreID: Int
    var choreName: String
    var lastTrackedTime: Date?
    var nextEstimatedExecutionTime: Date?
    var trackDateOnly: Bool
    var nextExecutionAssignedToUserID: Int?
    var isRescheduled: Bool
    var isReassigned: Bool
    @Relationship(deleteRule: .nullify) var nextExecutionAssignedUser: GrocyUser?

    enum CodingKeys: String, CodingKey {
        case id
        case choreID = "chore_id"
        case choreName = "chore_name"
        case lastTrackedTime = "last_tracked_time"
        case nextEstimatedExecutionTime = "next_estimated_execution_time"
        case trackDateOnly = "track_date_only"
        case nextExecutionAssignedToUserID = "next_execution_assigned_to_user_id"
        case isRescheduled = "is_rescheduled"
        case isReassigned = "is_reassigned"
        case nextExecutionAssignedUser = "next_execution_assigned_user"
    }

    required init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decodeFlexibleInt(forKey: .id)
            self.choreID = try container.decodeFlexibleInt(forKey: .choreID)
            self.choreName = try container.decode(String.self, forKey: .choreName)
            self.lastTrackedTime = getDateFromString(try container.decodeIfPresent(String.self, forKey: .lastTrackedTime))
            self.nextEstimatedExecutionTime = getDateFromString(try container.decodeIfPresent(String.self, forKey: .nextEstimatedExecutionTime))
            self.trackDateOnly = try container.decodeFlexibleBool(forKey: .trackDateOnly)
            self.nextExecutionAssignedToUserID = try container.decodeFlexibleIntIfPresent(forKey: .nextExecutionAssignedToUserID)
            self.isRescheduled = try container.decodeFlexibleBool(forKey: .isRescheduled)
            self.isReassigned = try container.decodeFlexibleBool(forKey: .isReassigned)
        } catch {
            throw APIError.decodingError(error: error)
        }
    }

    init(
        id: Int = -1,
        choreID: Int = 0,
        choreName: String = "",
        lastTrackedTime: Date? = nil,
        nextEstimatedExecutionTime: Date? = nil,
        trackDateOnly: Bool = false,
        nextExecutionAssignedToUserID: Int? = nil,
        isRescheduled: Bool = false,
        isReassigned: Bool = false
    ) {
        self.id = id
        self.choreID = choreID
        self.choreName = choreName
        self.lastTrackedTime = lastTrackedTime
        self.nextEstimatedExecutionTime = nextEstimatedExecutionTime
        self.trackDateOnly = trackDateOnly
        self.nextExecutionAssignedToUserID = nextExecutionAssignedToUserID
        self.isRescheduled = isRescheduled
        self.isReassigned = isReassigned
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(choreID, forKey: .choreID)
        try container.encode(choreName, forKey: .choreName)
        try container.encode(lastTrackedTime, forKey: .lastTrackedTime)
        try container.encode(nextEstimatedExecutionTime, forKey: .nextEstimatedExecutionTime)
        try container.encode(trackDateOnly, forKey: .trackDateOnly)
        try container.encode(nextExecutionAssignedToUserID, forKey: .nextExecutionAssignedToUserID)
        try container.encode(isRescheduled, forKey: .isRescheduled)
        try container.encode(isReassigned, forKey: .isReassigned)
        try container.encode(nextExecutionAssignedUser, forKey: .nextExecutionAssignedUser)
    }
}

typealias Chores = [Chore]
