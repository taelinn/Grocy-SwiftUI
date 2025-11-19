//
//  ServerProfileModel.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 17.11.25.
//

import Foundation
import SwiftData

@Model
final class LoginCustomHeader {
    @Attribute(.unique) var id: UUID
    var headerName: String
    var headerValue: String

    init(headerName: String, headerValue: String) {
        self.id = UUID()
        self.headerName = headerName
        self.headerValue = headerValue
    }
}

@Model
final class ServerProfile {
    @Attribute(.unique) var id: UUID
    var grocyServerURL: String
    var grocyAPIKey: String
    var useHassIngress: Bool
    var hassToken: String
    @Relationship(deleteRule: .cascade) var customHeaders: [LoginCustomHeader]
    var isActive: Bool

    init(grocyServerURL: String = "", grocyAPIKey: String = "", useHassIngress: Bool = false, hassToken: String = "", customHeaders: [LoginCustomHeader] = [], isActive: Bool = false) {
        self.id = UUID()
        self.grocyServerURL = grocyServerURL
        self.grocyAPIKey = grocyAPIKey
        self.useHassIngress = useHassIngress
        self.hassToken = hassToken
        self.customHeaders = customHeaders
        self.isActive = isActive
    }
}
