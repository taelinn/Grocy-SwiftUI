//
//  Grocy_SwiftUIApp.swift
//  Shared
//
//  Created by Georg Meissner on 13.11.20.
//

import SwiftData
import SwiftUI

@main
struct Grocy_MobileApp: App {
    @State private var grocyVM: GrocyViewModel

    @AppStorage("localizationKey") var localizationKey: String = "en"
    @AppStorage("onboardingNeeded") var onboardingNeeded: Bool = true
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("isDemoModus") var isDemoModus: Bool = false

    // For legacy migration reasons
    @AppStorage("grocyServerURL") var grocyServerURL: String = ""
    @AppStorage("grocyAPIKey") var grocyAPIKey: String = ""
    @AppStorage("useHassIngress") var useHassIngress: Bool = false
    @AppStorage("hassToken") var hassToken: String = ""

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            StockElement.self,
            ShoppingListItem.self,
            ShoppingListDescription.self,
            MDLocation.self,
            MDStore.self,
            MDQuantityUnit.self,
            MDQuantityUnitConversion.self,
            MDProductGroup.self,
            MDProduct.self,
            MDProductBarcode.self,
            StockJournalEntry.self,
            GrocyUser.self,
            StockEntry.self,
            GrocyUserSettings.self,
            StockProductDetails.self,
            StockProduct.self,
            VolatileStock.self,
            Recipe.self,
            StockLocation.self,
            SystemConfig.self,
            RecipePosResolvedElement.self,
            LoginCustomHeader.self,
            ServerProfile.self,
        ])

        let config = ModelConfiguration()
        do {
            modelContainer = try ModelContainer(for: schema, migrationPlan: .none, configurations: config)
            let modelContext = ModelContext(modelContainer)
            _grocyVM = State(initialValue: GrocyViewModel(modelContext: modelContext))
        } catch {
            // Reset store if there's a migration error
            ModelContainer.resetStore()

            // Try creating the container again
            do {
                modelContainer = try ModelContainer(for: schema, configurations: config)
                let modelContext = ModelContext(modelContainer)
                _grocyVM = State(initialValue: GrocyViewModel(modelContext: modelContext))
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }

        // Do migration for old AppStorage based to profile
        let modelContext = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<ServerProfile>()
        descriptor.fetchLimit = 0
        
        let numProfiles: Int = (try? modelContext.fetchCount(descriptor)) ?? 0
        if isLoggedIn && !isDemoModus && numProfiles == 0 && !grocyServerURL.isEmpty && !grocyAPIKey.isEmpty {
            let profile = ServerProfile(name: "", grocyServerURL: grocyServerURL, grocyAPIKey: grocyAPIKey, useHassIngress: useHassIngress, hassToken: hassToken)
            profile.isActive = true
            modelContext.insert(profile)
            let vm = grocyVM
            Task {
                await vm.setLoginModus()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if onboardingNeeded {
                OnboardingView()
            } else {
                if !isLoggedIn {
                    NavigationStack {
                        LoginView()
                    }
                } else {
                    ContentView()
                }
            }
        }
        .modelContainer(modelContainer)
        .environment(grocyVM)
        .environment(\.locale, Locale(identifier: localizationKey))
        .commands {
            SidebarCommands()
            //            #if os(macOS)
            //            AppCommands()
            //            #endif
        }
        #if os(macOS)
            Settings {
                if !onboardingNeeded, isLoggedIn {
                    SettingsView()
                        .environment(grocyVM)
                        .modelContainer(modelContainer)
                }
            }
        #endif
    }
}

extension ModelContainer {
    static func resetStore() {
        let storePath = URL.applicationSupportDirectory.appending(component: "default.store")
        try? FileManager.default.removeItem(at: storePath)
    }
}
