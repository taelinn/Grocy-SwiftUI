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
    var id: UUID = UUID()
    var headerName: String = ""
    var headerValue: String = ""
    var serverProfile: ServerProfile?

    init(headerName: String, headerValue: String) {
        self.id = UUID()
        self.headerName = headerName
        self.headerValue = headerValue
    }
}

@Model
final class ServerProfile {
    var id: UUID = UUID()
    var name: String = ""
    var grocyServerURL: String = ""
    var grocyAPIKey: String = ""
    var useHassIngress: Bool = false
    var hassToken: String = ""
    @Relationship(deleteRule: .cascade, inverse: \LoginCustomHeader.serverProfile) var customHeaders: [LoginCustomHeader]? = nil
    var userName: String = ""
    var displayName: String = ""
    @Attribute(.externalStorage) var profilePicture: Data?
    var barcodeBuddyURL: String?
    var barcodeBuddyAPIKey: String?

    init(name: String = "", grocyServerURL: String = "", grocyAPIKey: String = "", useHassIngress: Bool = false, hassToken: String = "", customHeaders: [LoginCustomHeader] = [], userName: String = "", displayName: String = "", profilePicture: Data? = nil, barcodeBuddyURL: String? = nil, barcodeBuddyAPIKey: String? = nil) {
        self.id = UUID()
        self.name = name
        self.grocyServerURL = grocyServerURL
        self.grocyAPIKey = grocyAPIKey
        self.useHassIngress = useHassIngress
        self.hassToken = hassToken
        self.customHeaders = customHeaders
        self.userName = userName
        self.displayName = displayName
        self.profilePicture = profilePicture
        self.barcodeBuddyURL = barcodeBuddyURL
        self.barcodeBuddyAPIKey = barcodeBuddyAPIKey
    }
    
    var hasBBConfigured: Bool {
        guard let url = barcodeBuddyURL, let key = barcodeBuddyAPIKey else {
            return false
        }
        return !url.isEmpty && !key.isEmpty
    }

    // MARK: - URL Validation

    /// Validates that the Grocy server URL uses HTTPS or is a local development server
    var isGrocyURLSecure: Bool {
        guard let url = URL(string: grocyServerURL.trimmingCharacters(in: .whitespaces)) else {
            return false
        }

        // Allow HTTPS
        if url.scheme == "https" {
            return true
        }

        // Allow local development servers (localhost, 127.0.0.1, .local domains)
        if url.scheme == "http" {
            if let host = url.host?.lowercased() {
                return host == "localhost" ||
                       host == "127.0.0.1" ||
                       host.hasPrefix("192.168.") ||
                       host.hasPrefix("10.") ||
                       host.hasPrefix("172.16.") ||
                       host.hasSuffix(".local")
            }
        }

        return false
    }

    /// Validates that the BarcodeBuddy URL uses HTTPS or is a local development server
    var isBBURLSecure: Bool {
        guard let urlString = barcodeBuddyURL,
              !urlString.isEmpty,
              let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            return true // Empty URL is OK (BB is optional)
        }

        // Allow HTTPS
        if url.scheme == "https" {
            return true
        }

        // Allow local development servers
        if url.scheme == "http" {
            if let host = url.host?.lowercased() {
                return host == "localhost" ||
                       host == "127.0.0.1" ||
                       host.hasPrefix("192.168.") ||
                       host.hasPrefix("10.") ||
                       host.hasPrefix("172.16.") ||
                       host.hasSuffix(".local")
            }
        }

        return false
    }

    /// Returns a user-friendly security warning message, or nil if URLs are secure
    var securityWarningMessage: String? {
        var warnings: [String] = []

        if !isGrocyURLSecure {
            warnings.append("Grocy server URL should use HTTPS for security")
        }

        if !isBBURLSecure {
            warnings.append("BarcodeBuddy URL should use HTTPS for security")
        }

        return warnings.isEmpty ? nil : warnings.joined(separator: "\n")
    }
}
