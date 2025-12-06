//
//  AppIntent.swift
//  Grocy Widget
//
//  Created by Georg Meißner on 06.12.25.
//

import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "Shows stock status overview." }

    enum StockFilter: String, AppEnum {
        case expiringSoon
        case overdue
        case expired
        case belowMinStock
        case all

        static var typeDisplayRepresentation: TypeDisplayRepresentation { "Stock Filter" }

        static let caseDisplayRepresentations: [StockFilter: DisplayRepresentation] = [
            .expiringSoon: "Expiring Soon",
            .overdue: "Overdue",
            .expired: "Expired",
            .belowMinStock: "Below Min. Stock",
            .all: "All",
        ]
    }

    @Parameter(title: "Default Filter", default: .all)
    var defaultFilter: StockFilter
}
