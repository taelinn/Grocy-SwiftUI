//
//  TaskExecutionModel.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 22.12.25.
//

struct TaskExecuteModel: Codable {
    let doneTime: String?

    enum CodingKeys: String, CodingKey {
        case doneTime = "done_time"
    }
}
