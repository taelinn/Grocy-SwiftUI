//
//  SettingsView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 28.10.20.
//

import SwiftUI
import SwiftData

enum SettingsNavigationItem: Hashable {
    case serverInfo
    case userInfo
    case appSettings
    case stockSettings
    case shoppingListSettings
    case choresSettings
    case barcodeBuddySettings
    case appIcon
    case appLog
    case aboutApp
}

struct SettingsView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.modelContext) private var modelContext

    @Environment(\.dismiss) var dismiss

    @State private var selection: SettingsNavigationItem? = nil
    @State private var isSyncingFavorites = false
    @State private var syncSuccessMessage: String?
    @State private var syncErrorMessage: String?

    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    var body: some View {
        NavigationStack {
            List {
            if isLoggedIn {
                Section("Grocy") {
                    NavigationLink(value: SettingsNavigationItem.serverInfo) {
                        Label("Information about Grocy Server", systemImage: MySymbols.info)
                            .foregroundStyle(.primary)
                    }
                    if let currentUser = grocyVM.currentUser {
                        NavigationLink(value: SettingsNavigationItem.userInfo) {
                            Label("Logged in as user \(currentUser.displayName)", systemImage: MySymbols.user)
                                .foregroundStyle(.primary)
                        }
                    }
                    Button(
                        action: {
                            grocyVM.deleteAllCachedData()
                        },
                        label: {
                            Label("Reset cache", systemImage: MySymbols.delete)
                                .foregroundStyle(.primary)
                        }
                    )
                    Button(
                        action: {
                            Task {
                                isSyncingFavorites = true
                                syncSuccessMessage = nil
                                syncErrorMessage = nil
                                
                                do {
                                    try await grocyVM.syncFavoritesFromServer(modelContext: modelContext)
                                    syncSuccessMessage = "Quick Add favorites synced successfully"
                                } catch {
                                    syncErrorMessage = "Failed to sync favorites: \(error.localizedDescription)"
                                    GrocyLogger.error("Sync favorites error: \(error)")
                                }
                                
                                isSyncingFavorites = false
                            }
                        },
                        label: {
                            HStack {
                                Label("Sync Quick Add favorites", systemImage: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.primary)
                                if isSyncingFavorites {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                    )
                    .disabled(isSyncingFavorites)
                    Button(
                        action: {
                            grocyVM.logout()
                        },
                        label: {
                            Label("Logout", systemImage: MySymbols.logout)
                                .foregroundStyle(.red)
                        }
                    )
                }
            }

            Section("Grocy settings") {
                NavigationLink(value: SettingsNavigationItem.appSettings) {
                    Label("App settings", systemImage: MySymbols.app)
                        .foregroundStyle(.primary)
                }
                NavigationLink(value: SettingsNavigationItem.stockSettings) {
                    Label("Stock settings", systemImage: MySymbols.stockOverview)
                        .foregroundStyle(.primary)
                }
                NavigationLink(value: SettingsNavigationItem.shoppingListSettings) {
                    Label("Shopping list settings", systemImage: MySymbols.shoppingList)
                        .foregroundStyle(.primary)
                }
                NavigationLink(value: SettingsNavigationItem.barcodeBuddySettings) {
                    Label("BarcodeBuddy settings", systemImage: "barcode.viewfinder")
                        .foregroundStyle(.primary)
                }
            }

            Section("App") {
                NavigationLink(value: SettingsNavigationItem.appIcon) {
                    Label("App icon", systemImage: "app.badge")
                        .foregroundStyle(.primary)
                }
                NavigationLink(value: SettingsNavigationItem.appLog) {
                    Label("App log", systemImage: MySymbols.logFile)
                        .foregroundStyle(.primary)
                }
                NavigationLink(value: SettingsNavigationItem.aboutApp) {
                    Label("About this app", systemImage: MySymbols.info)
                        .foregroundStyle(.primary)
                }
            }
            .alert("Success", isPresented: .constant(syncSuccessMessage != nil)) {
                Button("OK") {
                    syncSuccessMessage = nil
                }
            } message: {
                Text(syncSuccessMessage ?? "")
            }
            .alert("Error", isPresented: .constant(syncErrorMessage != nil)) {
                Button("OK") {
                    syncErrorMessage = nil
                }
            } message: {
                Text(syncErrorMessage ?? "")
            }
        }
        .navigationDestination(for: SettingsNavigationItem.self) { destination in
            switch destination {
            case .serverInfo:
                GrocyInfoView(systemInfo: grocyVM.systemInfo)
            case .userInfo:
                GrocyUserInfoView(grocyUser: grocyVM.currentUser)
            case .appSettings:
                SettingsAppView()
            case .stockSettings:
                SettingsStockView()
            case .shoppingListSettings:
                SettingsShoppingListView()
            case .choresSettings:
                SettingsChoresView()
            case .barcodeBuddySettings:
                if let profile = grocyVM.selectedServerProfile {
                    BBSettingsView(serverProfile: profile)
                } else {
                    Text("No server profile found")
                }
            case .appIcon:
                AppIconSettingsView()
            case .appLog:
                LogView()
            case .aboutApp:
                AboutView()
            }
        }
            .navigationTitle("Settings")
            .task {
                await grocyVM.requestData(additionalObjects: [.system_info, .current_user])
            }
        }
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        SettingsView()
    }
}
