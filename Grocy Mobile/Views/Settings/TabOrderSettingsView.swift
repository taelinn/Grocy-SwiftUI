//
//  TabOrderSettingsView.swift
//  Grocy Mobile
//
//  Created for custom tab ordering feature
//

import SwiftUI

struct TabOrderSettingsView: View {
    @AppStorage("devMode") private var devMode: Bool = false
    
    // Existing enable toggles for backward compatibility
    @AppStorage("enableQuickScan") var enableQuickScan: Bool = true
    @AppStorage("enableQuickAdd") var enableQuickAdd: Bool = true
    @AppStorage("enableBarcodeBuddy") var enableBarcodeBuddy: Bool = true
    @AppStorage("enableStockOverview") var enableStockOverview: Bool = true
    @AppStorage("enableShoppingList") var enableShoppingList: Bool = true
    @AppStorage("enableRecipes") var enableRecipes: Bool = true
    @AppStorage("enableChores") var enableChores: Bool = true
    @AppStorage("enableTasks") var enableTasks: Bool = true
    @AppStorage("enableMasterData") var enableMasterData: Bool = true
    
    @State private var tabOrderManager = TabOrderManager()
    @State private var tabs: [TabDefinition] = []
    @State private var showResetAlert = false
    
    var body: some View {
        Form {
            Section {
                Text("Drag tabs to reorder them. Toggle to show or hide. Settings is always last and cannot be hidden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Section("Tab Order") {
                ForEach(filteredTabs) { tab in
                    HStack(spacing: 12) {
                        // Drag handle (only for non-pinned tabs)
                        if !tab.isPinned {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                                .font(.body)
                        } else {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                        
                        // Tab icon
                        Image(systemName: tab.icon)
                            .frame(width: 28)
                            .foregroundStyle(tab.isEnabled ? .primary : .secondary)
                        
                        // Tab name
                        Text(tab.name)
                            .foregroundStyle(tab.isEnabled ? .primary : .secondary)
                        
                        Spacer()
                        
                        // Toggle (only for hideable tabs)
                        if tab.isHideable {
                            Toggle("", isOn: Binding(
                                get: { tab.isEnabled },
                                set: { newValue in
                                    updateTabEnabled(tabId: tab.id, isEnabled: newValue)
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    moveTab(from: source, to: destination)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("Reset to Default Order", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Customize Tabs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .onAppear {
            loadTabs()
        }
        .alert("Reset Tab Order", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetTabs()
            }
        } message: {
            Text("This will restore the default tab order and show all tabs. Are you sure?")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Filter out recipes in non-dev mode
    private var filteredTabs: [TabDefinition] {
        if devMode {
            return tabs
        } else {
            return tabs.filter { $0.id != "recipes" }
        }
    }
    
    // MARK: - Methods
    
    private func loadTabs() {
        // Sync with current AppStorage values
        tabs = tabOrderManager.syncWithAppStorage(
            enableQuickScan: enableQuickScan,
            enableQuickAdd: enableQuickAdd,
            enableBarcodeBuddy: enableBarcodeBuddy,
            enableStockOverview: enableStockOverview,
            enableShoppingList: enableShoppingList,
            enableRecipes: enableRecipes,
            enableChores: enableChores,
            enableTasks: enableTasks,
            enableMasterData: enableMasterData
        )
    }
    
    private func updateTabEnabled(tabId: String, isEnabled: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        
        tabs[index] = TabDefinition(
            id: tabs[index].id,
            name: tabs[index].name,
            icon: tabs[index].icon,
            isEnabled: isEnabled,
            sortOrder: tabs[index].sortOrder,
            isPinned: tabs[index].isPinned,
            isHideable: tabs[index].isHideable
        )
        
        // Update AppStorage for backward compatibility
        updateAppStorageValue(tabId: tabId, isEnabled: isEnabled)
        
        // Save to persistence
        tabOrderManager.saveTabOrder(tabs)
    }
    
    private func moveTab(from source: IndexSet, to destination: Int) {
        // Get the actual tabs we're working with (filtered)
        var workingTabs = filteredTabs
        
        // Don't allow moving pinned tabs
        if let sourceIndex = source.first,
           sourceIndex < workingTabs.count,
           workingTabs[sourceIndex].isPinned {
            return
        }
        
        // Perform the move
        workingTabs.move(fromOffsets: source, toOffset: destination)
        
        // Update sort order
        for (index, _) in workingTabs.enumerated() {
            if let originalIndex = tabs.firstIndex(where: { $0.id == workingTabs[index].id }) {
                tabs[originalIndex] = TabDefinition(
                    id: tabs[originalIndex].id,
                    name: tabs[originalIndex].name,
                    icon: tabs[originalIndex].icon,
                    isEnabled: tabs[originalIndex].isEnabled,
                    sortOrder: index,
                    isPinned: tabs[originalIndex].isPinned,
                    isHideable: tabs[originalIndex].isHideable
                )
            }
        }
        
        // Ensure settings stays at the end with high sort order
        if let settingsIndex = tabs.firstIndex(where: { $0.id == "settings" }) {
            tabs[settingsIndex] = TabDefinition(
                id: tabs[settingsIndex].id,
                name: tabs[settingsIndex].name,
                icon: tabs[settingsIndex].icon,
                isEnabled: tabs[settingsIndex].isEnabled,
                sortOrder: 999,
                isPinned: tabs[settingsIndex].isPinned,
                isHideable: tabs[settingsIndex].isHideable
            )
        }
        
        // Save
        tabOrderManager.saveTabOrder(tabs)
    }
    
    private func resetTabs() {
        // Reset to defaults
        tabOrderManager.resetToDefaults()
        
        // Reset all AppStorage values
        enableQuickScan = true
        enableQuickAdd = true
        enableBarcodeBuddy = true
        enableStockOverview = true
        enableShoppingList = true
        enableRecipes = true
        enableChores = true
        enableTasks = true
        enableMasterData = true
        
        // Reload
        loadTabs()
    }
    
    private func updateAppStorageValue(tabId: String, isEnabled: Bool) {
        switch tabId {
        case "quickScan":
            enableQuickScan = isEnabled
        case "quickAdd":
            enableQuickAdd = isEnabled
        case "barcodeBuddy":
            enableBarcodeBuddy = isEnabled
        case "stockOverview":
            enableStockOverview = isEnabled
        case "shoppingList":
            enableShoppingList = isEnabled
        case "recipes":
            enableRecipes = isEnabled
        case "chores":
            enableChores = isEnabled
        case "tasks":
            enableTasks = isEnabled
        case "masterData":
            enableMasterData = isEnabled
        default:
            break
        }
    }
}

#Preview {
    NavigationStack {
        TabOrderSettingsView()
    }
}
