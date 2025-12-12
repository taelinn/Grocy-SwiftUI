//
//  Grocy_SwiftUIApp.swift
//  Shared
//
//  Created by Georg Meissner on 13.11.20.
//

import SwiftData
import SwiftUI

// MARK: - Deep Link State

@Observable
class DeepLinkManager {
    var pendingStockFilter: ProductStatus?
    
    func apply(deepLink: GrocyDeepLink) {
        if case .stock(let filter) = deepLink {
            pendingStockFilter = filter
        }
    }
    
    func consume() {
        pendingStockFilter = nil
    }
}

@main
struct Grocy_MobileApp: App {
    @State private var grocyVM: GrocyViewModel
    @State private var deepLinkManager = DeepLinkManager()

    @AppStorage("localizationKey") var localizationKey: String = "en"
    @AppStorage("onboardingNeeded") var onboardingNeeded: Bool = true
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("isDemoModus") var isDemoModus: Bool = false
    @AppStorage("selectedServerProfileID") private var selectedServerProfileID: UUID?

    // For legacy migration reasons
    @AppStorage("grocyServerURL") var grocyServerURL: String = ""
    @AppStorage("grocyAPIKey") var grocyAPIKey: String = ""
    @AppStorage("useHassIngress") var useHassIngress: Bool = false
    @AppStorage("hassToken") var hassToken: String = ""

    let modelContainer: ModelContainer
    let profileModelContainer: ModelContainer

    init() {
        // Main container schema (all data except ServerProfile and LoginCustomHeader)
        let mainSchema = Schema([
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
            MDTaskCategory.self,
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
            RecipeFulfilment.self,
            MDChore.self,
            Chore.self,
            ChoreLogEntry.self,
        ])

        // Profile container schema (ServerProfile and LoginCustomHeader with iCloud sync)
        let profileSchema = Schema([
            ServerProfile.self,
            LoginCustomHeader.self,
        ])

        let mainConfig = ModelConfiguration(
            schema: mainSchema,
            groupContainer: .identifier("group.georgappdev.Grocy"),
            cloudKitDatabase: .none
        )
        let profileConfig = ModelConfiguration(
            schema: profileSchema,
            url: URL.applicationSupportDirectory.appending(component: "profiles.store"),
            allowsSave: true,
            cloudKitDatabase: isRunningOnSimulator() ? .none : .private("iCloud.georgappdev.Grocy")
        )
        
        // Initialize profile container
        do {
            profileModelContainer = try ModelContainer(for: profileSchema, migrationPlan: .none, configurations: profileConfig)
        } catch {
            // Reset profile store if there's a migration error
            ModelContainer.resetProfileStore()

            // Try creating the container again
            do {
                profileModelContainer = try ModelContainer(for: profileSchema, configurations: profileConfig)
            } catch {
                fatalError("Failed to create profile ModelContainer after reset: \(error)")
            }
            isLoggedIn = false
        }

        // Initialize main container
        do {
            modelContainer = try ModelContainer(for: mainSchema, migrationPlan: .none, configurations: mainConfig)
            let modelContext = ModelContext(modelContainer)
            _grocyVM = State(initialValue: GrocyViewModel(modelContext: modelContext, profileModelContext: ModelContext(profileModelContainer)))
        } catch {
            // Reset store if there's a migration error
            ModelContainer.resetStore()

            // Try creating the container again
            do {
                modelContainer = try ModelContainer(for: mainSchema, configurations: mainConfig)
                let modelContext = ModelContext(modelContainer)
                _grocyVM = State(initialValue: GrocyViewModel(modelContext: modelContext, profileModelContext: ModelContext(profileModelContainer)))
            } catch {
                fatalError("Failed to create main ModelContainer after reset: \(error)")
            }
            isLoggedIn = false
        }

        // Do migration for old AppStorage based to profile
        let profileModelContext = ModelContext(profileModelContainer)
        var descriptor = FetchDescriptor<ServerProfile>()
        descriptor.fetchLimit = 0
        
        let numProfiles: Int = (try? profileModelContext.fetchCount(descriptor)) ?? 0
        if isLoggedIn && !isDemoModus && numProfiles == 0 && !grocyServerURL.isEmpty && !grocyAPIKey.isEmpty {
            let profile = ServerProfile(name: "", grocyServerURL: grocyServerURL, grocyAPIKey: grocyAPIKey, useHassIngress: useHassIngress, hassToken: hassToken)
            selectedServerProfileID = profile.id
            profileModelContext.insert(profile)
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
                        .environment(deepLinkManager)
                        .onOpenURL { url in
                            if let deepLink = GrocyDeepLink(url: url) {
                                deepLinkManager.apply(deepLink: deepLink)
                            }
                        }
                }
            }
        }
        .modelContainer(modelContainer)
        .modelContainer(profileModelContainer)
        .environment(grocyVM)
        .environment(\.profileModelContext, ModelContext(profileModelContainer))
        .environment(\.profileModelContainer, profileModelContainer)
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
                        .modelContainer(profileModelContainer)
                        .environment(\.profileModelContext, ModelContext(profileModelContainer))
                }
            }
        #endif
    }
}

extension ModelContainer {
    static func resetStore() {
        let storePath = sharedModelContainerURL()
        try? FileManager.default.removeItem(at: storePath)
    }

    static func resetProfileStore() {
        let storePath = URL.applicationSupportDirectory.appending(component: "profiles.store")
        try? FileManager.default.removeItem(at: storePath)
    }
}

func sharedModelContainerURL() -> URL {
    let appGroupID = "group.georgappdev.Grocy"
    guard let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
        fatalError("Could not access shared app group container")
    }
    return sharedContainerURL.appending(component: "default.store")
}
