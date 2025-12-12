//
//  ChoreExecuteModel.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 12.12.25.
//

import Foundation

struct ChoreExecuteModel: Codable {
    let trackedTime: String?
    let doneBy: Int?
    let skipped: Bool?

    enum CodingKeys: String, CodingKey {
        case trackedTime = "tracked_time"
        case doneBy = "done_by"
        case skipped = "skipped"
    }
}
