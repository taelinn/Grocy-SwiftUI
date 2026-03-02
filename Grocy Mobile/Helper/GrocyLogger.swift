//
//  GrocyLogger.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 16.06.25.
//

import OSLog

enum GrocyLogger {
    private static let logger = Logger(subsystem: "com.roadworkstechnology.grocymobile", category: "AppLogger")

    static func error(_ message: String) {
        logger.error("\(message, privacy: .private)")
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .private)")
    }

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .private)")
    }

    static func warning(_ message: String) {
        logger.warning("\(message, privacy: .private)")
    }
}
