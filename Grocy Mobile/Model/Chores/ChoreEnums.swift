//
//  ChoreEnums.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 10.12.25.
//
import SwiftUI

enum ChorePeriodType: String, Codable, CaseIterable {
    case manually = "manually"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case hourly = "hourly"
    case adaptive = "adaptive"

    var localizedName: LocalizedStringKey {
        switch self {
        case .manually:
            return LocalizedStringKey("Manually")
        case .daily:
            return LocalizedStringKey("Daily")
        case .weekly:
            return LocalizedStringKey("Weekly")
        case .monthly:
            return LocalizedStringKey("Monthly")
        case .yearly:
            return LocalizedStringKey("Yearly")
        case .hourly:
            return LocalizedStringKey("Hourly")
        case .adaptive:
            return LocalizedStringKey("Adaptive")
        }
    }
}

enum ChoreAssignmentType: String, Codable, CaseIterable {
    case noAssignment = "no-assignment"
    case whoLeastDidFirst = "who-least-did-first"
    case random = "random"
    case inAlphabeticalOrder = "in-alphabetical-order"

    var localizedName: LocalizedStringKey {
        switch self {
        case .noAssignment:
            return LocalizedStringKey("No assignment")
        case .whoLeastDidFirst:
            return LocalizedStringKey("Who least did first")
        case .random:
            return LocalizedStringKey("Random")
        case .inAlphabeticalOrder:
            return LocalizedStringKey("In alphabetical order")
        }
    }
}
