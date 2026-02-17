//
//  SettingsShoppingListView.swift
//  Grocy Mobile
//

import EventKit
import SwiftData
import SwiftUI

struct SettingsShoppingListView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query(filter: #Predicate<MDStore> { $0.active }, sort: \MDStore.name) var mdStores: [MDStore]
    @Query var shoppingListDescriptions: ShoppingListDescriptions

    @AppStorage("devMode") private var devMode: Bool = false
    @AppStorage(StoreReminderMappings.syncEnabledKey) private var reminderSyncEnabled: Bool = false

    @State private var useAutoAddBelowMinStockAmount: Bool = false
    @State private var isFirst: Bool = true
    @State private var storeReminderMappings: [Int: String] = [:]
    @State private var defaultReminderList: String = ""
    @State private var availableReminderLists: [String] = []
    @State private var hasReminderAccess: Bool = false
    @State private var isRequestingAccess: Bool = false
    @State private var isSyncing: Bool = false
    @State private var syncResultMessage: String? = nil

    private let dataToUpdate: [ObjectEntities] = [.shopping_lists, .shopping_locations]

    var body: some View {
        Form {
            Section("Shopping list") {
                ServerSettingsToggle(
                    settingKey: GrocyUserSettings.CodingKeys.shoppingListAutoAddBelowMinStockAmount.rawValue,
                    description: "Automatically add products that are below their defined min. stock amount to the shopping list",
                    icon: MySymbols.amount,
                    toggleFeedback: $useAutoAddBelowMinStockAmount
                )
                if useAutoAddBelowMinStockAmount {
                    ServerSettingsObjectPicker(
                        settingKey: GrocyUserSettings.CodingKeys.shoppingListAutoAddBelowMinStockAmountListID.rawValue,
                        description: "Shopping list",
                        icon: MySymbols.shoppingList,
                        objects: .shoppingLists
                    )
                }
            }

            Section("Shopping list to stock workflow") {
                ServerSettingsToggle(
                    settingKey: GrocyUserSettings.CodingKeys.shoppingListToStockWorkflowAutoSubmitWhenPrefilled.rawValue,
                    description: "Automatically do the booking using the last price and the amount of the shopping list item, if the product has \"Default due days\" set",
                    icon: MySymbols.stockOverview
                )
            }

            Section {
                Toggle(isOn: $reminderSyncEnabled) {
                    Label("Sync to iOS Reminders", systemImage: "checklist")
                }
                .onChange(of: reminderSyncEnabled) { _, newValue in
                    if newValue && !hasReminderAccess {
                        Task { await requestReminderAccess() }
                    }
                }

                if reminderSyncEnabled {
                    if !hasReminderAccess {
                        Button {
                            Task { await requestReminderAccess() }
                        } label: {
                            Label(isRequestingAccess ? "Requesting access..." : "Grant Reminders Access", systemImage: "bell.badge")
                        }
                        .disabled(isRequestingAccess)
                    } else {
                        storeListMappingsSection
                        syncControlsSection
                    }
                }
            } header: {
                Text("Reminders Sync")
            } footer: {
                if reminderSyncEnabled && hasReminderAccess {
                    Text("Shopping list items for each store will be synced to the selected Reminders list. Only items with a store assigned are synced.")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shopping list settings")
        .task {
            if isFirst {
                await grocyVM.requestData(objects: dataToUpdate)
                storeReminderMappings = StoreReminderMappings.load()
                defaultReminderList = UserDefaults.standard.string(forKey: StoreReminderMappings.defaultListKey) ?? ""
                hasReminderAccess = ReminderStore.shared.hasAccess
                if hasReminderAccess {
                    loadAvailableLists()
                }
                isFirst = false
            }
        }
        .onDisappear {
            Task {
                await grocyVM.requestData(additionalObjects: [.user_settings])
            }
        }
    }

    // MARK: - Store → Reminder List Mapping UI

    @ViewBuilder
    private var storeListMappingsSection: some View {
        // Default fallback list for items with no store assigned
        Picker("Other / No store", selection: $defaultReminderList) {
            Text("None").tag("")
            ForEach(availableReminderLists, id: \.self) { listName in
                Text(listName).tag(listName)
            }
        }
        .onChange(of: defaultReminderList) { _, newValue in
            UserDefaults.standard.set(newValue.isEmpty ? nil : newValue, forKey: StoreReminderMappings.defaultListKey)
        }

        if !mdStores.isEmpty {
            ForEach(mdStores, id: \.id) { store in
                storeMappingRow(store: store)
            }
        }
    }

    private func storeMappingRow(store: MDStore) -> some View {
        let binding = Binding<String>(
            get: { storeReminderMappings[store.id] ?? "" },
            set: { newValue in
                let oldValue = storeReminderMappings[store.id]
                if newValue.isEmpty {
                    // Remove mapping and clear old reminders
                    storeReminderMappings.removeValue(forKey: store.id)
                    if let old = oldValue {
                        try? ReminderStore.shared.clearGrocyReminders(from: old)
                    }
                } else {
                    storeReminderMappings[store.id] = newValue
                }
                StoreReminderMappings.save(storeReminderMappings)
            }
        )

        return Picker(store.name, selection: binding) {
            Text("None").tag("")
            ForEach(availableReminderLists, id: \.self) { listName in
                Text(listName).tag(listName)
            }
        }
    }

    // MARK: - Sync Controls

    @ViewBuilder
    private var syncControlsSection: some View {
        Button {
            Task { await performSync() }
        } label: {
            if isSyncing {
                Label("Syncing...", systemImage: "arrow.triangle.2.circlepath")
            } else {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .disabled(isSyncing)

        if let message = syncResultMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func requestReminderAccess() async {
        isRequestingAccess = true
        do {
            try await ReminderStore.shared.requestAccess()
            hasReminderAccess = ReminderStore.shared.hasAccess
            if hasReminderAccess {
                loadAvailableLists()
            }
        } catch {
            GrocyLogger.error("Reminders access error: \(error)")
            reminderSyncEnabled = false
        }
        isRequestingAccess = false
    }

    private func loadAvailableLists() {
        availableReminderLists = ReminderStore.shared.availableLists().map { $0.title }
    }

    private func performSync() async {
        isSyncing = true
        syncResultMessage = nil
        do {
            let count = try await grocyVM.syncShoppingListToReminders(
                mappings: storeReminderMappings,
                defaultList: defaultReminderList.isEmpty ? nil : defaultReminderList
            )
            syncResultMessage = "Synced \(count) item(s) to Reminders"
        } catch {
            syncResultMessage = "Sync failed: \(error.localizedDescription)"
            GrocyLogger.error("Reminder sync failed: \(error)")
        }
        isSyncing = false
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        SettingsShoppingListView()
    }
}
