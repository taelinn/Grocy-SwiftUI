//
//  AppIconManager.swift
//  Grocy Mobile
//
//  Manages alternate app icon selection
//

import SwiftUI

@Observable
class AppIconManager {
    static let shared = AppIconManager()
    
    // Available app icons
    enum AppIcon: String, CaseIterable, Identifiable {
        case primary = "AppIcon"
        case blueOnWhite = "AppIcon-BlueOnWhite"
        case orangeOnBlack = "AppIcon-OrangeOnBlack"
        case blackOnOrange = "AppIcon-BlackOnOrange"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .primary:
                return "White on Blue"
            case .blueOnWhite:
                return "Blue on White"
            case .orangeOnBlack:
                return "Orange on Black"
            case .blackOnOrange:
                return "Black on Orange"
            }
        }
        
        var iconName: String? {
            switch self {
            case .primary:
                return nil  // nil represents the default icon
            default:
                return rawValue
            }
        }
        
        var previewImageName: String {
            switch self {
            case .primary:
                return "AppIcon-Preview"
            case .blueOnWhite:
                return "AppIcon-BlueOnWhite-Preview"
            case .orangeOnBlack:
                return "AppIcon-OrangeOnBlack-Preview"
            case .blackOnOrange:
                return "AppIcon-BlackOnOrange-Preview"
            }
        }
    }
    
    var currentIcon: AppIcon {
        get {
            guard let iconName = UIApplication.shared.alternateIconName else {
                return .primary
            }
            return AppIcon.allCases.first { $0.iconName == iconName } ?? .primary
        }
    }
    
    func setIcon(_ icon: AppIcon) async throws {
        guard UIApplication.shared.supportsAlternateIcons else {
            throw AppIconError.notSupported
        }
        
        try await UIApplication.shared.setAlternateIconName(icon.iconName)
        GrocyLogger.info("App icon changed to: \(icon.displayName)")
    }
}

enum AppIconError: LocalizedError {
    case notSupported
    case changeFailed
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Alternate icons are not supported on this device"
        case .changeFailed:
            return "Failed to change app icon"
        }
    }
}
