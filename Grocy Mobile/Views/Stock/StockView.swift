//
//  StockView.swift
//  grocy-ios
//
//  Created by Georg Meissner on 13.10.20.
//

import SwiftData
import SwiftUI

enum StockColumn {
    case product, productGroup, amount, value, nextDueDate, caloriesPerStockQU, calories
}

enum StockInteraction: Hashable {
    case purchaseProduct
    case consumeProduct
    case transferProduct
    case inventoryProduct
    case stockJournal
    case addToShL(stockElement: StockElement)
    case productPurchase(stockElement: StockElement)
    case productConsume(stockElement: StockElement)
    case productTransfer(stockElement: StockElement)
    case productInventory(stockElement: StockElement)
    case productOverview(stockElement: StockElement)
    case productJournal(stockElement: StockElement)
}

struct StockView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<StockElement> { $0.amount > 0 }) var stock: [StockElement]
    @Query(filter: #Predicate<StockLocation> { $0.amount > 0 }) var stockLocations: StockLocations
    @Query(sort: \MDProduct.name, order: .forward) var mdProducts: MDProducts
    @Query(sort: \MDProductGroup.id, order: .forward) var mdProductGroups: MDProductGroups
    @Query(sort: \MDLocation.name, order: .forward) var mdLocations: MDLocations
    @Query(sort: \MDQuantityUnit.id, order: .forward) var mdQuantityUnits: MDQuantityUnits
    @Query(sort: \ShoppingListItem.id, order: .forward) var shoppingList: [ShoppingListItem]
    @Query(sort: \StockEntry.id, order: .forward) var stockEntries: StockEntries
    @Query var volatileStockList: [VolatileStock]
    var volatileStock: VolatileStock? {
        return volatileStockList.first
    }
    @Query var userSettingsList: GrocyUserSettingsList
    var userSettings: GrocyUserSettings? {
        return userSettingsList.first
    }
    @State private var searchString: String = ""
    @State private var showingFilterSheet = false

    #if os(iOS)
        @AppStorage("iPhoneTabNavigation") var iPhoneTabNavigation: Bool = true
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private enum StockGrouping: Identifiable {
        case none, productGroup, nextDueDate, lastPurchased, minStockAmount, parentProduct, defaultLocation
        var id: Int {
            hashValue
        }
    }
    @State private var stockGrouping: StockGrouping = .none
    @State private var sortSetting = [KeyPathComparator(\StockElement.productID)]
    @State private var sortOrder: SortOrder = .forward

    @State private var filteredLocationID: Int?
    @State private var filteredProductGroupID: Int?
    @State private var filteredStatus: ProductStatus = .all

    @State var selectedStockElement: StockElement? = nil

    // Cached filtered/grouped results to prevent blocking during filter changes
    @State private var cachedFilteredStock: [StockElement] = []
    @State private var cachedGroupedStock: [AnyHashable: [StockElement]] = [:]
    @State private var filterComputationTask: Task<Void, Never>?

    private let dataToUpdate: [ObjectEntities] = [.products, .shopping_locations, .locations, .product_groups, .quantity_units, .shopping_lists, .shopping_list, .stock, .stock_current_locations]
    private let additionalDataToUpdate: [AdditionalEntities] = [.stock, .volatileStock, .system_config, .user_settings]
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate, additionalObjects: additionalDataToUpdate)
    }

    var numExpiringSoon: Int? {
        volatileStock?.dueProducts.count
    }

    var numOverdue: Int? {
        volatileStock?.overdueProducts.count
    }

    var numExpired: Int? {
        volatileStock?.expiredProducts.count
    }

    var numBelowStock: Int? {
        volatileStock?.missingProducts.count
    }

    var missingStock: Stock {
        var missingStockList: Stock = []
        for missingProduct in volatileStock?.missingProducts ?? [] {
            if !(missingProduct.isPartlyInStock) {
                if let foundProduct = mdProducts.first(where: { $0.id == missingProduct.productID }) {
                    let missingStockElement = StockElement(
                        amount: 0,
                        amountAggregated: 0,
                        value: 0.0,
                        bestBeforeDate: nil,
                        amountOpened: 0,
                        amountOpenedAggregated: 0,
                        isAggregatedAmount: false,
                        dueType: foundProduct.dueType,
                        productID: missingProduct.productID,
                        product: foundProduct
                    )
                    missingStockList.append(missingStockElement)
                }
            }
        }
        return missingStockList
    }

    var filteredAndSearchedStock: [StockElement] {
        cachedFilteredStock
    }

    var groupedStock: [AnyHashable: [StockElement]] {
        cachedGroupedStock
    }

    private func computeFilteredAndGroupedStock() {
        filterComputationTask?.cancel()

        // Capture required values before detaching to avoid MainActor access issues
        let searchString = self.searchString
        let filteredLocationID = self.filteredLocationID
        let filteredProductGroupID = self.filteredProductGroupID
        let filteredStatus = self.filteredStatus
        let stockGrouping = self.stockGrouping
        let sortSetting = self.sortSetting
        let stock = self.stock
        let missingStock = self.missingStock
        let stockLocations = self.stockLocations
        let mdProducts = self.mdProducts
        let mdProductGroups = self.mdProductGroups
        let mdLocations = self.mdLocations
        let volatileStock = self.volatileStock
        let stockEntries = self.stockEntries
        
        // Pre-convert stock element dates to avoid MainActor access in background task
        let stockWithDates: [(element: StockElement, dueDate: Date?)] = stock.map { element in
            (element, element.bestBeforeDate)
        }
        let missingStockWithDates: [(element: StockElement, dueDate: Date?)] = missingStock.map { element in
            (element, element.bestBeforeDate)
        }
        
        // Pre-convert min stock amounts to strings to avoid MainActor access in background task
        let minStockAmountMap = (stock + missingStock).reduce(into: [Int: String]()) { dict, element in
            dict[element.productID] = element.product?.minStockAmount.formattedAmount ?? ""
        }
        
        // Pre-convert last purchased dates to avoid MainActor access in background task
        let lastPurchasedMap = stockEntries.reduce(into: [Int: Date?]()) { dict, item in
            if let purchasedDate = item.purchasedDate {
                if let existingDate = dict[item.productID], let existingDate = existingDate, purchasedDate > existingDate {
                    dict[item.productID] = purchasedDate
                } else if dict[item.productID] == nil {
                    dict[item.productID] = purchasedDate
                }
            }
        }
        
        // Pre-compute product group names to avoid MainActor access in background task
        let productGroupNameMap = mdProductGroups.reduce(into: [Int: String]()) { dict, group in
            dict[group.id] = group.name
        }
        
        // Pre-compute product names to avoid MainActor access in background task
        _ = mdProducts.reduce(into: [Int: String]()) { dict, product in
            dict[product.id] = product.name
        }
        
        // Pre-compute parent product names to avoid MainActor access in background task
        let parentProductNameMap = mdProducts.reduce(into: [Int: String]()) { dict, product in
            if let parentID = product.parentProductID {
                dict[product.id] = mdProducts.first(where: { $0.id == parentID })?.name ?? ""
            } else {
                dict[product.id] = ""
            }
        }
        
        // Pre-compute location names to avoid MainActor access in background task
        let locationNameMap = mdLocations.reduce(into: [Int: String]()) { dict, location in
            dict[location.id] = location.name
        }

        filterComputationTask = Task.detached(priority: .userInitiated) {
            // Cache frequently accessed data
            let dueProductIDs = Set(volatileStock?.dueProducts.map { $0.productID } ?? [])
            let expiredProductIDs = Set(volatileStock?.expiredProducts.map { $0.productID } ?? [])
            let overdueProductIDs = Set(volatileStock?.overdueProducts.map { $0.productID } ?? [])
            let missingProductIDs = Set(volatileStock?.missingProducts.map { $0.productID } ?? [])

            // First use predicate for simple conditions
            let simplePredicate = #Predicate<StockElement> { stockElement in
                !(stockElement.product?.hideOnStockOverview ?? false)
                    && (searchString.isEmpty || stockElement.product?.name.localizedStandardContains(searchString) ?? false)
                    && (filteredProductGroupID == nil || stockElement.product?.productGroupID == filteredProductGroupID)
            }

            // Then apply complex filters using Swift
            let stockForFiltering = stockWithDates.map { $0.element } + missingStockWithDates.map { $0.element }
            let filtered = stockForFiltering
                .filter { (try? simplePredicate.evaluate($0)) ?? false }
                .filter { stockElement in
                    // Location filter
                    filteredLocationID == nil || stockLocations.contains(where: { $0.productID == stockElement.productID && $0.locationID == filteredLocationID })
                }
                .filter { stockElement in
                    // Status filters - using cached Sets for O(1) lookup
                    let productID = stockElement.productID
                    return filteredStatus == .all
                        || (filteredStatus == .belowMinStock && missingProductIDs.contains(productID))
                        || (filteredStatus == .expiringSoon && dueProductIDs.contains(productID))
                        || (filteredStatus == .overdue && overdueProductIDs.contains(productID) && !expiredProductIDs.contains(productID))
                        || (filteredStatus == .expired && expiredProductIDs.contains(productID))
                }
                .sorted(using: sortSetting)

            // Create maps for grouping - use Date objects as keys for proper chronological sorting
            let nextDueDateMap = (stockWithDates + missingStockWithDates).reduce(into: [UUID: Date?]()) { dict, item in
                dict[item.element.id] = item.dueDate
            }
            
            let lastPurchasedDateMap = lastPurchasedMap

            // Compute grouped stock using pre-captured lookup data to avoid MainActor access
            let grouped: [AnyHashable: [StockElement]] = {
                switch stockGrouping {
                case .none:
                    return Dictionary(
                        grouping: filtered,
                        by: { _ in
                            "" as AnyHashable
                        }
                    )
                case .productGroup:
                    return Dictionary(
                        grouping: filtered,
                        by: { element in
                            if let groupID = element.product?.productGroupID {
                                return productGroupNameMap[groupID] as AnyHashable? ?? "" as AnyHashable
                            }
                            return "" as AnyHashable
                        }
                    )
                case .nextDueDate:
                    return Dictionary(
                        grouping: filtered,
                        by: { element in
                            if let date = nextDueDateMap[element.id] {
                                return date as AnyHashable? ?? NSNull() as AnyHashable
                            } else {
                                return NSNull() as AnyHashable
                            }
                        }
                    )
                case .lastPurchased:
                    return Dictionary(
                        grouping: filtered,
                        by: { element in
                            if let date = lastPurchasedDateMap[element.productID] {
                                return date as AnyHashable? ?? NSNull() as AnyHashable
                            } else {
                                return NSNull() as AnyHashable
                            }
                        }
                    )
                case .minStockAmount:
                    return Dictionary(
                        grouping: filtered,
                        by: { element in
                            Double(minStockAmountMap[element.productID] ?? "") as AnyHashable? ?? 0 as AnyHashable
                        }
                    )
                case .parentProduct:
                    return Dictionary(
                        grouping: filtered,
                        by: { element in
                            parentProductNameMap[element.productID] as AnyHashable? ?? "" as AnyHashable
                        }
                    )
                case .defaultLocation:
                    return Dictionary(
                        grouping: filtered,
                        by: { element in
                            if let locationID = element.product?.locationID {
                                return locationNameMap[locationID] as AnyHashable? ?? "" as AnyHashable
                            }
                            return "" as AnyHashable
                        }
                    )
                }
            }()

            // Update UI on main thread
            await MainActor.run {
                self.cachedFilteredStock = filtered
                self.cachedGroupedStock = grouped
            }
        }
    }

    var summedValue: Double {
        let values = stock.map { $0.value }
        return values.reduce(0, +)
    }

    var summedValueStr: String {
        return "\(summedValue.formatted(.number.precision(.fractionLength(0...2)))) \(getCurrencySymbol())"
    }

    var stockListContent: some View {
        let sortedGroups = Array(groupedStock).sorted { a, b in
            if let dateA = a.key as? Date, let dateB = b.key as? Date { return dateA < dateB }
            if let numA = a.key as? Double, let numB = b.key as? Double { return numA < numB }
            return String(describing: a.key) < String(describing: b.key)
        }
        
        return ForEach(sortedGroups, id: \.key) { groupKey, groupElements in
            Section(
                content: {
                    ForEach(
                        groupElements.sorted(using: sortSetting),
                        id: \.productID
                    ) { stockElement in
                        StockTableRow(
                            mdQuantityUnits: mdQuantityUnits,
                            shoppingList: shoppingList,
                            mdProductGroups: mdProductGroups,
                            volatileStock: volatileStock,
                            userSettings: userSettings,
                            stockElement: stockElement,
                            selectedStockElement: $selectedStockElement
                        )
                    }
                },
                header: {
                    let dateFormatter: DateFormatter = {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .none
                        return formatter
                    }()
                    
                    if stockGrouping == .productGroup, (groupKey as? String)?.isEmpty ?? false {
                        Text("Ungrouped")
                            .italic()
                    } else if stockGrouping == .none {
                        EmptyView()
                    } else if stockGrouping == .minStockAmount, let numValue = groupKey as? Double {
                        Text(String(format: "%.0f", numValue)).bold()
                    } else if stockGrouping == .nextDueDate || stockGrouping == .lastPurchased {
                        if let date = groupKey as? Date {
                            Text(dateFormatter.string(from: date)).bold()
                        } else if groupKey is NSNull {
                            Text("Unknown").italic()
                        } else {
                            Text(String(describing: groupKey)).bold()
                        }
                    } else {
                        let groupName = groupKey as? String ?? String(describing: groupKey)
                        Text(groupName).bold()
                    }
                }
            )
        }
    }

    var body: some View {
        List {
            Section {
                StockFilterActionsView(filteredStatus: $filteredStatus, numExpiringSoon: numExpiringSoon, numOverdue: numOverdue, numExpired: numExpired, numBelowStock: numBelowStock)
                    .listRowInsets(EdgeInsets())
            }

            if grocyVM.failedToLoadObjects.filter({ dataToUpdate.contains($0) }).count > 0 {
                ServerProblemView()
            } else if (stock + missingStock).isEmpty {
                ContentUnavailableView("Stock is empty.", systemImage: MySymbols.stockOverview)
            } else if filteredAndSearchedStock.isEmpty {
                ContentUnavailableView.search
            }
            stockListContent
        }
        .navigationTitle("Stock overview")
        .searchable(text: $searchString, prompt: "Search")
        .refreshable {
            await updateData()
        }
        .task {
            await updateData()
            // Compute initial filtered/grouped stock after data loads
            computeFilteredAndGroupedStock()
        }
        .onChange(of: filteredLocationID) { _, _ in
            computeFilteredAndGroupedStock()
        }
        .onChange(of: filteredProductGroupID) { _, _ in
            computeFilteredAndGroupedStock()
        }
        .onChange(of: filteredStatus) { _, _ in
            computeFilteredAndGroupedStock()
        }
        .onChange(of: searchString) { _, _ in
            computeFilteredAndGroupedStock()
        }
        .onChange(of: stockGrouping) { _, _ in
            computeFilteredAndGroupedStock()
        }
        .onChange(of: sortSetting) { _, _ in
            computeFilteredAndGroupedStock()
        }
        .onChange(of: stock) { _, _ in
            computeFilteredAndGroupedStock()
        }
        .onChange(of: volatileStock) { _, _ in
            computeFilteredAndGroupedStock()
        }
        .toolbar(content: {
            #if os(iOS)
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: { showingFilterSheet = true }) {
                        Label("Filter", systemImage: MySymbols.filter)
                    }
                    sortMenu
                }
                ToolbarSpacer(.fixed)
                if horizontalSizeClass == .compact && iPhoneTabNavigation {
                    ToolbarItem(placement: .automatic) {
                        NavigationLink(value: StockInteraction.stockJournal) {
                            Label("Stock journal", systemImage: MySymbols.stockJournal)
                        }
                    }
                    ToolbarSpacer(.fixed)
                }
            #endif
            #if os(iOS)
                ToolbarItemGroup(placement: horizontalSizeClass == .compact ? .secondaryAction : .primaryAction) {
                    NavigationLink(value: StockInteraction.inventoryProduct) {
                        Label("Inventory", systemImage: MySymbols.inventory)
                    }
                    NavigationLink(value: StockInteraction.transferProduct) {
                        Label("Transfer", systemImage: MySymbols.transfer)
                    }
                    NavigationLink(value: StockInteraction.consumeProduct) {
                        Label("Consume", systemImage: MySymbols.consume)
                    }
                    NavigationLink(value: StockInteraction.purchaseProduct) {
                        Label("Purchase", systemImage: MySymbols.purchase)
                    }
                }
            #elseif os(macOS)
                ToolbarItemGroup(
                    placement: .automatic,
                    content: {
                        Button(action: { showingFilterSheet = true }) {
                            Label("Filter", systemImage: MySymbols.filter)
                        }
                        .popover(
                            isPresented: $showingFilterSheet,
                            content: {
                                VStack {
                                    StockFilterView(filteredLocationID: $filteredLocationID, filteredProductGroupID: $filteredProductGroupID, filteredStatus: $filteredStatus)
                                    HStack {
                                        Button(
                                            role: .destructive,
                                            action: {
                                                filteredLocationID = nil
                                                filteredProductGroupID = nil
                                                filteredStatus = .all
                                                showingFilterSheet = false
                                            }
                                        )
                                        Spacer()
                                        Button(
                                            role: .confirm,
                                            action: {
                                                showingFilterSheet = false
                                            }
                                        )

                                    }
                                    .padding()
                                }
                                .frame(width: 400, height: 200)
                            }
                        )
                        sortMenu
                        RefreshButton(updateData: { Task { await updateData() } })
                    }
                )
            #endif
        })
        .navigationDestination(
            for: StockInteraction.self,
            destination: { interaction in
                switch interaction {
                case .stockJournal:
                    StockJournalView()
                case .inventoryProduct:
                    InventoryProductView()
                case .transferProduct:
                    TransferProductView()
                case .consumeProduct:
                    ConsumeProductView()
                case .purchaseProduct:
                    PurchaseProductView()
                case .productPurchase(let stockElement):
                    PurchaseProductView(stockElement: stockElement)
                case .productConsume(let stockElement):
                    ConsumeProductView(stockElement: stockElement)
                case .productTransfer(let stockElement):
                    TransferProductView(stockElement: stockElement)
                case .productInventory(let stockElement):
                    InventoryProductView(stockElement: stockElement)
                case .productOverview(let stockElement):
                    StockProductInfoView(stockElement: stockElement)
                case .productJournal(let stockElement):
                    StockJournalView(stockElement: stockElement)
                case .addToShL(let stockElement):
                    ShoppingListEntryFormView(isNewShoppingListEntry: true, productIDToSelect: stockElement.productID)
                }
            }
        )
        .navigationDestination(
            for: StockElement.self,
            destination: { stockElement in
                StockEntriesView(stockElement: stockElement)
            }
        )
        #if os(iOS)
            .sheet(isPresented: $showingFilterSheet) {
                NavigationStack {
                    StockFilterView(filteredLocationID: $filteredLocationID, filteredProductGroupID: $filteredProductGroupID, filteredStatus: $filteredStatus)
                    .navigationTitle("Filter")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(
                            placement: .confirmationAction,
                            content: {
                                Button(
                                    role: .confirm,
                                    action: {
                                        showingFilterSheet = false
                                    }
                                )
                            }
                        )
                        ToolbarItem(
                            placement: .cancellationAction,
                            content: {
                                Button(
                                    role: .destructive,
                                    action: {
                                        filteredLocationID = nil
                                        filteredProductGroupID = nil
                                        filteredStatus = .all
                                        showingFilterSheet = false
                                    }
                                )
                            }
                        )
                    }
                }
                .presentationDetents([.medium])

            }
        #endif
    }

    var sortMenu: some View {
        Menu(
            content: {
                Picker(
                    "Group by",
                    systemImage: MySymbols.groupBy,
                    selection: $stockGrouping,
                    content: {
                        Label("None", systemImage: MySymbols.product)
                            .labelStyle(.titleAndIcon)
                            .tag(StockGrouping.none)
                        Label("Product group", systemImage: MySymbols.amount)
                            .labelStyle(.titleAndIcon)
                            .tag(StockGrouping.productGroup)
                        Label("Next due date", systemImage: MySymbols.date)
                            .labelStyle(.titleAndIcon)
                            .tag(StockGrouping.nextDueDate)
                        Label("Last purchased", systemImage: MySymbols.date)
                            .labelStyle(.titleAndIcon)
                            .tag(StockGrouping.lastPurchased)
                        Label("Min. stock amount", systemImage: MySymbols.amount)
                            .labelStyle(.titleAndIcon)
                            .tag(StockGrouping.minStockAmount)
                        Label("Parent product", systemImage: MySymbols.product)
                            .labelStyle(.titleAndIcon)
                            .tag(StockGrouping.parentProduct)
                        Label("Default location", systemImage: MySymbols.location)
                            .labelStyle(.titleAndIcon)
                            .tag(StockGrouping.defaultLocation)
                    }
                )
                #if os(iOS)
                    .pickerStyle(.menu)
                #else
                    .pickerStyle(.inline)
                #endif

                Picker(
                    "Sort category",
                    systemImage: MySymbols.sortCategory,
                    selection: $sortSetting,
                    content: {
                        if sortOrder == .forward {
                            Label("Name", systemImage: MySymbols.product)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\StockElement.product?.name, order: .forward)])
                            Label("Due date", systemImage: MySymbols.date)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\StockElement.bestBeforeDate, order: .forward)])
                            Label("Amount", systemImage: MySymbols.amount)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\StockElement.amount, order: .forward)])
                        } else {
                            Label("Name", systemImage: MySymbols.product)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\StockElement.product?.name, order: .reverse)])
                            Label("Due date", systemImage: MySymbols.date)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\StockElement.bestBeforeDate, order: .reverse)])
                            Label("Amount", systemImage: MySymbols.amount)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\StockElement.amount, order: .reverse)])
                        }
                    }
                )
                #if os(iOS)
                    .pickerStyle(.menu)
                #else
                    .pickerStyle(.inline)
                #endif

                Picker(
                    "Sort order",
                    systemImage: MySymbols.sortOrder,
                    selection: $sortOrder,
                    content: {
                        Label("Ascending", systemImage: MySymbols.sortForward)
                            .labelStyle(.titleAndIcon)
                            .tag(SortOrder.forward)
                        Label("Descending", systemImage: MySymbols.sortReverse)
                            .labelStyle(.titleAndIcon)
                            .tag(SortOrder.reverse)
                    }
                )
                #if os(iOS)
                    .pickerStyle(.menu)
                #else
                    .pickerStyle(.inline)
                #endif
                .onChange(of: sortOrder) {
                    if var sortElement = sortSetting.first {
                        sortElement.order = sortOrder
                        sortSetting = [sortElement]
                    }
                }
            },
            label: {
                Label("Sort", systemImage: MySymbols.sort)
            }
        )
    }
}

#Preview {
    ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
        StockView()
            .preferredColorScheme(scheme)
    }
}
