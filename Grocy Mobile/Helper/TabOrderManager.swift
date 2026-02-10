//
//  TabOrderManager.swift
//  Grocy Mobile
//
//  Created for custom tab ordering feature
//

import SwiftUI
import SwiftData

/// Represents a tab definition with metadata
struct TabDefinition: Identifiable, Codable, Equatable {
    let id: String              // Unique identifier (e.g., "quickScan")
    let name: String            // Display name
    let icon: String            // SF Symbol name
    var isEnabled: Bool         // Show/hide toggle
    var sortOrder: Int          // Order position
    let isPinned: Bool          // Cannot be moved (Settings)
    let isHideable: Bool        // Can be hidden by user
    
    init(id: String, name: String, icon: String, isEnabled: Bool = true, sortOrder: Int, isPinned: Bool = false, isHideable: Bool = true) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.isPinned = isPinned
        self.isHideable = isHideable
    }
}

/// Manages tab ordering and persistence
@Observable
class TabOrderManager {
    
    // MARK: - Default Tab Definitions
    
    static let defaultTabs: [TabDefinition] = [
        TabDefinition(id: "quickScan", name: "Quick Scan", icon: MySymbols.barcodeScan, sortOrder: 0),
        TabDefinition(id: "quickAdd", name: "Quick Add", icon: "bolt.fill", sortOrder: 1),
        TabDefinition(id: "barcodeBuddy", name: "New Scans", icon: "list.bullet.clipboard", sortOrder: 2),
        TabDefinition(id: "stockOverview", name: "Stock overview", icon: MySymbols.stockOverview, sortOrder: 3),
        TabDefinition(id: "shoppingList", name: "Shopping list", icon: MySymbols.shoppingList, sortOrder: 4),
        TabDefinition(id: "recipes", name: "Recipes", icon: MySymbols.recipe, sortOrder: 5),
        TabDefinition(id: "chores", name: "Chores overview", icon: MySymbols.chores, sortOrder: 6),
        TabDefinition(id: "tasks", name: "Tasks", icon: MySymbols.tasks, sortOrder: 7),
        TabDefinition(id: "masterData", name: "Master data", icon: MySymbols.masterData, sortOrder: 8),
        TabDefinition(id: "settings", name: "Settings", icon: MySymbols.settings, sortOrder: 999, isPinned: true, isHideable: false)
    ]
    
    // MARK: - Storage Keys
    
    private static let tabOrderKey = "customTabOrder"
    
    // MARK: - Public Methods
    
    /// Load tab order from storage or return defaults
    func loadTabOrder() -> [TabDefinition] {
        guard let data = UserDefaults.standard.data(forKey: Self.tabOrderKey),
              let savedTabs = try? JSONDecoder().decode([TabDefinition].self, from: data) else {
            return Self.defaultTabs
        }
        
        // Merge saved tabs with defaults to handle new tabs added in app updates
        return mergeSavedWithDefaults(saved: savedTabs, defaults: Self.defaultTabs)
    }
    
    /// Save tab order to storage
    func saveTabOrder(_ tabs: [TabDefinition]) {
        if let encoded = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(encoded, forKey: Self.tabOrderKey)
        }
    }
    
    /// Reset to default order
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: Self.tabOrderKey)
    }
    
    /// Get enabled tabs in order, respecting feature flags
    func getEnabledTabs(systemConfig: SystemConfig?) -> [TabDefinition] {
        var tabs = loadTabOrder()
        
        // Filter based on enabled state
        tabs = tabs.filter { $0.isEnabled }
        
        // Filter based on system feature flags
        tabs = tabs.filter { tab in
            switch tab.id {
            case "stockOverview":
                return systemConfig?.featureFlagStock != false
            case "shoppingList":
                return systemConfig?.featureFlagShoppinglist != false
            case "recipes":
                return systemConfig?.featureFlagRecipes != false
            case "chores":
                return systemConfig?.featureFlagChores != false
            case "tasks":
                return systemConfig?.featureFlagTasks != false
            default:
                return true
            }
        }
        
        // Sort by sort order
        tabs.sort { $0.sortOrder < $1.sortOrder }
        
        return tabs
    }
    
    /// Sync enabled states with AppStorage properties
    func syncWithAppStorage(
        enableQuickScan: Bool,
        enableQuickAdd: Bool,
        enableBarcodeBuddy: Bool,
        enableStockOverview: Bool,
        enableShoppingList: Bool,
        enableRecipes: Bool,
        enableChores: Bool,
        enableTasks: Bool,
        enableMasterData: Bool
    ) -> [TabDefinition] {
        var tabs = loadTabOrder()
        
        for index in tabs.indices {
            switch tabs[index].id {
            case "quickScan":
                tabs[index].isEnabled = enableQuickScan
            case "quickAdd":
                tabs[index].isEnabled = enableQuickAdd
            case "barcodeBuddy":
                tabs[index].isEnabled = enableBarcodeBuddy
            case "stockOverview":
                tabs[index].isEnabled = enableStockOverview
            case "shoppingList":
                tabs[index].isEnabled = enableShoppingList
            case "recipes":
                tabs[index].isEnabled = enableRecipes
            case "chores":
                tabs[index].isEnabled = enableChores
            case "tasks":
                tabs[index].isEnabled = enableTasks
            case "masterData":
                tabs[index].isEnabled = enableMasterData
            default:
                break
            }
        }
        
        saveTabOrder(tabs)
        return tabs
    }
    
    // MARK: - Private Methods
    
    /// Merge saved tabs with defaults to handle app updates
    private func mergeSavedWithDefaults(saved: [TabDefinition], defaults: [TabDefinition]) -> [TabDefinition] {
        var merged = saved
        
        // Add any new tabs from defaults that don't exist in saved
        for defaultTab in defaults {
            if !merged.contains(where: { $0.id == defaultTab.id }) {
                merged.append(defaultTab)
            }
        }
        
        // Update properties of existing tabs from defaults (preserving user's order and enabled state)
        for index in merged.indices {
            if let defaultTab = defaults.first(where: { $0.id == merged[index].id }) {
                // Update name and icon in case they changed
                merged[index] = TabDefinition(
                    id: merged[index].id,
                    name: defaultTab.name,
                    icon: defaultTab.icon,
                    isEnabled: merged[index].isEnabled,
                    sortOrder: merged[index].sortOrder,
                    isPinned: defaultTab.isPinned,
                    isHideable: defaultTab.isHideable
                )
            }
        }
        
        // Ensure settings is always last
        merged.sort { tab1, tab2 in
            if tab1.isPinned && !tab2.isPinned { return false }
            if !tab1.isPinned && tab2.isPinned { return true }
            return tab1.sortOrder < tab2.sortOrder
        }
        
        return merged
    }
}
