//
//  AppTabNavigation.swift
//  Grocy-SwiftUI (iOS)
//
//  Created by Georg Meissner on 13.11.20.
//

import SwiftData
import SwiftUI

private enum TabNavigationItem: String, Codable {
    case quickScanMode = "quickScanMode"
    case barcodeBuddy = "barcodeBuddy"
    case quickAdd = "quickAdd"
    case stockOverview = "stockOverview"
    case stockJournal = "stockJournal"
    case shoppingList = "shoppingList"
    case masterData = "masterData"
    case activities = "activities"
    case settings = "settings"
    case openFoodFacts = "openFoodFacts"
    case recipes = "recipes"
    case chores = "chores"
    case tasks = "tasks"
    case stockInteraction = "stockInteraction"
    case purchaseProduct = "purchaseProduct"
    case consumeProduct = "consumeProduct"
    case transferProduct = "transferProduct"
    case inventoryProduct = "inventoryProduct"
    case mdProducts = "mdProducts"
    case mdLocations = "mdLocations"
    case mdStores = "mdStores"
    case mdQuantityUnits = "mdQuantityUnits"
    case mdProductGroups = "mdProductGroups"
    case mdChores = "mdChores"
    case mdTaskCategories = "mdTaskCategories"
}

struct AppTabNavigation: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @AppStorage("tabSelection") private var tabSelection: TabNavigationItem = .stockOverview
    @AppStorage("appTabCustomization") private var appTabCustomization: TabViewCustomization
    @AppStorage("devMode") private var devMode: Bool = false

    @AppStorage("enableQuickScan") var enableQuickScan: Bool = true
    @AppStorage("enableQuickAdd") var enableQuickAdd: Bool = true
    @AppStorage("enableBarcodeBuddy") var enableBarcodeBuddy: Bool = true
    @AppStorage("enableStockOverview") var enableStockOverview: Bool = true
    @AppStorage("enableShoppingList") var enableShoppingList: Bool = true
    @AppStorage("enableRecipes") var enableRecipes: Bool = true
    @AppStorage("enableChores") var enableChores: Bool = true
    @AppStorage("enableTasks") var enableTasks: Bool = true
    @AppStorage("enableMasterData") var enableMasterData: Bool = true

    @Environment(DeepLinkManager.self) var deepLinkManager

    @Query var systemConfigList: [SystemConfig]
    var systemConfig: SystemConfig? {
        systemConfigList.first
    }
    
    @State private var tabOrderManager = TabOrderManager()

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            // iPhone: Dynamic tabs based on user's custom order
            iPhoneTabView
        } else {
            // iPad: Traditional fixed layout with sections
            iPadTabView
        }
        #else
        // macOS: Traditional layout
        macOSTabView
        #endif
    }
    
    // MARK: - iPhone TabView
    
    private var iPhoneTabView: some View {
        TabView(selection: $tabSelection) {
            // Fixed 5 tabs - no "More" menu
            Tab("Quick Scan", systemImage: MySymbols.barcodeScan, value: TabNavigationItem.quickScanMode) {
                NavigationStack {
                    QuickScanModeView()
                }
            }
            .customizationID("georgappdev.Grocy.quickScanMode")
            .hidden(!enableQuickScan)
            
            Tab("Quick Add", systemImage: "bolt.fill", value: TabNavigationItem.quickAdd) {
                NavigationStack {
                    QuickAddTabView()
                }
            }
            .customizationID("com.roadworkstechnology.grocymobile.quickAdd")
            .hidden(!enableQuickAdd)
            
            Tab("New Scans", systemImage: "list.bullet.clipboard", value: TabNavigationItem.barcodeBuddy) {
                BarcodeBuddyTabView()
            }
            .customizationID("georgappdev.Grocy.barcodeBuddy")
            .hidden(!enableBarcodeBuddy)
            
            Tab("Stock", systemImage: MySymbols.stockOverview, value: TabNavigationItem.stockOverview) {
                NavigationStack {
                    StockView()
                }
            }
            .customizationID("georgappdev.Grocy.stockOverview")
            
            Tab("Settings", systemImage: MySymbols.settings, value: TabNavigationItem.settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onAppear {
            Task {
                await grocyVM.requestData(additionalObjects: [.system_config])
            }
            if deepLinkManager.pendingStockFilter != nil {
                tabSelection = .stockOverview
            }
        }
        .onChange(of: deepLinkManager.pendingStockFilter) { _, newValue in
            if newValue != nil {
                tabSelection = .stockOverview
            }
        }
    }
    
    // MARK: - iPad/macOS TabView
    
    private var iPadTabView: some View {
        tabViewContent
    }
    
    private var macOSTabView: some View {
        tabViewContent
    }
    
    private var tabViewContent: some View {
        TabView(selection: $tabSelection) {
            Group {
                Tab("Quick Scan", systemImage: MySymbols.barcodeScan, value: TabNavigationItem.quickScanMode) {
                    NavigationStack {
                        QuickScanModeView()
                    }
                }
                .customizationID("georgappdev.Grocy.quickScanMode")
                .hidden(!enableQuickScan)
                
                Tab("Quick Add", systemImage: "bolt.fill", value: TabNavigationItem.quickAdd) {
                    NavigationStack {
                        QuickAddTabView()
                    }
                }
                .customizationID("com.roadworkstechnology.grocymobile.quickAdd")
                .hidden(!enableQuickAdd)

                Tab("New Scans", systemImage: "list.bullet.clipboard", value: TabNavigationItem.barcodeBuddy) {
                    BarcodeBuddyTabView()
                }
                .customizationID("georgappdev.Grocy.barcodeBuddy")
                .hidden(!enableBarcodeBuddy)

                Tab("Stock overview", systemImage: MySymbols.stockOverview, value: TabNavigationItem.stockOverview) {
                    NavigationStack {
                        StockView()
                    }
                }
                .customizationID("georgappdev.Grocy.stockOverview")
                .hidden(systemConfig?.featureFlagStock == false || !enableStockOverview)

                Tab("Shopping list", systemImage: MySymbols.shoppingList, value: TabNavigationItem.shoppingList) {
                    NavigationStack {
                        ShoppingListView()
                    }
                }
                .customizationID("georgappdev.Grocy.shoppingList")
                .hidden(systemConfig?.featureFlagShoppinglist == false || !enableShoppingList)

                Tab("Recipes", systemImage: MySymbols.recipe, value: TabNavigationItem.recipes) {
                    NavigationStack {
                        RecipesView()
                    }
                }
                .customizationID("georgappdev.Grocy.recipes")
                .hidden(systemConfig?.featureFlagRecipes == false || !enableRecipes)

                Tab("Chores overview", systemImage: MySymbols.chores, value: TabNavigationItem.chores) {
                    NavigationStack {
                        ChoresView()
                    }
                }
                .customizationID("georgappdev.Grocy.chores")
                .hidden(systemConfig?.featureFlagChores == false || !enableChores)

                Tab("Tasks", systemImage: MySymbols.tasks, value: TabNavigationItem.tasks) {
                    NavigationStack {
                        TasksView()
                    }
                }
                .customizationID("georgappdev.Grocy.tasks")
                .hidden(systemConfig?.featureFlagTasks == false || !enableTasks)
            }

            if horizontalSizeClass != .compact {
                TabSection(
                    "Stock interaction",
                    content: {
                        Tab("Purchase", systemImage: MySymbols.purchase, value: TabNavigationItem.purchaseProduct) {
                            PurchaseProductView()
                        }
                        .customizationID("georgappdev.Grocy.purchaseProduct")

                        Tab("Consume", systemImage: MySymbols.consume, value: TabNavigationItem.consumeProduct) {
                            ConsumeProductView()
                        }
                        .customizationID("georgappdev.Grocy.consumeProduct")

                        Tab("Transfer", systemImage: MySymbols.transfer, value: TabNavigationItem.transferProduct) {
                            TransferProductView()
                        }
                        .customizationID("georgappdev.Grocy.transferProduct")

                        Tab("Inventory", systemImage: MySymbols.inventory, value: TabNavigationItem.inventoryProduct) {
                            InventoryProductView()
                        }
                        .customizationID("georgappdev.Grocy.inventoryProduct")
                    }
                )
                .tabPlacement(.sidebarOnly)
                .customizationID("georgappdev.Grocy.stockInteraction")
                .hidden(systemConfig?.featureFlagStock == false)
            }

            if horizontalSizeClass != .compact {
                TabSection(
                    "Master data",
                    content: {
                        Tab("Products", systemImage: MySymbols.product, value: TabNavigationItem.mdProducts) {
                            MDProductsView()
                        }
                        .customizationID("georgappdev.Grocy.mdProducts")

                        Tab("Locations", systemImage: MySymbols.location, value: TabNavigationItem.mdLocations) {
                            MDLocationsView()
                        }
                        .customizationID("georgappdev.Grocy.mdLocations")
                        .hidden(systemConfig?.featureFlagStock == false)

                        Tab("Stores", systemImage: MySymbols.store, value: TabNavigationItem.mdStores) {
                            MDStoresView()
                        }
                        .customizationID("georgappdev.Grocy.mdStores")
                        .hidden(systemConfig?.featureFlagStock == false)

                        Tab("Quantity units", systemImage: MySymbols.quantityUnit, value: TabNavigationItem.mdQuantityUnits) {
                            MDQuantityUnitsView()
                        }
                        .customizationID("georgappdev.Grocy.mdQuantityUnits")

                        Tab("Product groups", systemImage: MySymbols.productGroup, value: TabNavigationItem.mdProductGroups) {
                            MDProductGroupsView()
                        }
                        .customizationID("georgappdev.Grocy.mdProductGroups")

                        Tab("Chores", systemImage: MySymbols.chores, value: TabNavigationItem.mdChores) {
                            MDChoresView()
                        }
                        .customizationID("georgappdev.Grocy.mdChores")
                        .hidden(systemConfig?.featureFlagChores == false)

                        Tab("Task categories", systemImage: MySymbols.tasks, value: TabNavigationItem.mdTaskCategories) {
                            MDTaskCategoriesView()
                        }
                        .customizationID("georgappdev.Grocy.mdTaskCategories")
                        .hidden(systemConfig?.featureFlagTasks == false)
                    }
                )
                .tabPlacement(.sidebarOnly)
                .customizationID("georgappdev.Grocy.masterDataSection")
            }

            Group {
                Tab("Master data", systemImage: MySymbols.masterData, value: TabNavigationItem.masterData) {
                    MasterDataView()
                }
                .hidden(!enableMasterData)
                #if os(iOS)
                    .defaultVisibility(.hidden, for: .sidebar)
                #endif
                .customizationID("georgappdev.Grocy.masterData")

                #if os(iOS)
                Tab("Settings", systemImage: MySymbols.settings, value: TabNavigationItem.settings) {
                    SettingsView()
                }
                #endif
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($appTabCustomization)
        .tabViewSidebarHeader(content: {
            Image("grocy-logo")
                .resizable()
                .scaledToFit()
        })
        #if os(iOS)
            .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .onAppear {
            Task {
                await grocyVM.requestData(additionalObjects: [.system_config])
            }
            if deepLinkManager.pendingStockFilter != nil {
                tabSelection = .stockOverview
            }
        }
        .onChange(of: deepLinkManager.pendingStockFilter) { _, newValue in
            if newValue != nil {
                tabSelection = .stockOverview
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Get ordered and enabled tabs for iPhone
    private var orderedTabs: [TabDefinition] {
        tabOrderManager.getEnabledTabs(systemConfig: systemConfig)
    }
    
    
    // MARK: - Helper Methods
    
    /// Create a tab based on tab definition
    @TabContentBuilder<TabNavigationItem>
    private func createTab(for tabDef: TabDefinition) -> some TabContent<TabNavigationItem> {
        switch tabDef.id {
        case "quickScan":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.quickScanMode) {
                NavigationStack {
                    QuickScanModeView()
                }
            }
            .customizationID("georgappdev.Grocy.quickScanMode")
            
        case "quickAdd":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.quickAdd) {
                NavigationStack {
                    QuickAddTabView()
                }
            }
            .customizationID("com.roadworkstechnology.grocymobile.quickAdd")
            
        case "barcodeBuddy":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.barcodeBuddy) {
                BarcodeBuddyTabView()
            }
            .customizationID("georgappdev.Grocy.barcodeBuddy")
            
        case "stockOverview":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.stockOverview) {
                NavigationStack {
                    StockView()
                }
            }
            .customizationID("georgappdev.Grocy.stockOverview")
            
        case "shoppingList":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.shoppingList) {
                NavigationStack {
                    ShoppingListView()
                }
            }
            .customizationID("georgappdev.Grocy.shoppingList")
            
        case "recipes":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.recipes) {
                NavigationStack {
                    RecipesView()
                }
            }
            .customizationID("georgappdev.Grocy.recipes")
            
        case "chores":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.chores) {
                NavigationStack {
                    ChoresView()
                }
            }
            .customizationID("georgappdev.Grocy.chores")
            
        case "tasks":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.tasks) {
                NavigationStack {
                    TasksView()
                }
            }
            .customizationID("georgappdev.Grocy.tasks")
            
        case "masterData":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.masterData) {
                MasterDataView()
            }
            .customizationID("georgappdev.Grocy.masterData")
            
        case "settings":
            Tab(tabDef.name, systemImage: tabDef.icon, value: TabNavigationItem.settings) {
                SettingsView()
            }
            
        default:
            Tab("Unknown", systemImage: "questionmark", value: TabNavigationItem.stockOverview) {
                Text("Unknown tab: \(tabDef.id)")
            }
        }
    }
    

}

#Preview {
    AppTabNavigation()
}
