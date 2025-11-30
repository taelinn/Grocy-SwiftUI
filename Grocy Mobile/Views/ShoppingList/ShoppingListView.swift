//
//  ShoppingListView.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 26.11.20.
//

import SwiftData
import SwiftUI

struct ShoppingListItemWrapped {
    let shoppingListItem: ShoppingListItem
    let product: MDProduct?
}

enum ShoppingListInteraction: Hashable, Identifiable {
    case newShoppingList
    case newShoppingListEntry
    case purchase(item: ShoppingListItem)
    case autoPurchase(item: ShoppingListItem)

    var id: Self { self }
}

@Observable
class ShoppingListInteractionNavigationRouter {
    var presentedInteraction: ShoppingListInteraction?

    func present(_ interaction: ShoppingListInteraction) {
        presentedInteraction = interaction
    }

    func dismiss() {
        presentedInteraction = nil
    }
}

struct ShoppingListView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query(sort: \ShoppingListDescription.id, order: .forward) var shoppingListDescriptions: ShoppingListDescriptions
    @Query(sort: \ShoppingListItem.id, order: .forward) var shoppingList: [ShoppingListItem]
    @Query(sort: \MDProduct.name, order: .forward) var mdProducts: MDProducts
    @Query(sort: \MDProductGroup.id, order: .forward) var mdProductGroups: MDProductGroups
    @Query(sort: \MDStore.id, order: .forward) var mdStores: MDStores
    @Query(sort: \MDQuantityUnit.id, order: .forward) var mdQuantityUnits: MDQuantityUnits
    @Query(sort: \MDQuantityUnitConversion.id, order: .forward) var mdQuantityUnitConversions: MDQuantityUnitConversions
    @Query var userSettingsList: GrocyUserSettingsList
    var userSettings: GrocyUserSettings? {
        userSettingsList.first
    }

    @State private var selectedShoppingListID: Int = -1

    @State private var firstAppear: Bool = true

    @State private var searchString: String = ""
    @State private var filteredStatus: ShoppingListStatus = .all
    private enum ShoppingListGrouping: Identifiable {
        case none, productGroup, defaultStore
        var id: Int {
            hashValue
        }
    }
    @State private var shoppingListGrouping: ShoppingListGrouping = .productGroup
    @State private var sortSetting = [KeyPathComparator(\ShoppingListItemWrapped.product?.name)]
    @State private var sortOrder: SortOrder = .forward

    @State private var showFilterSheet: Bool = false
    
    @State private var shoppingListInteractionRouter = ShoppingListInteractionNavigationRouter()

    @State private var showSHLDeleteAlert: Bool = false
    @State private var showClearListAlert: Bool = false
    @State private var showClearDoneAlert: Bool = false
    @State private var shlItemToDelete: ShoppingListItem? = nil
    @State private var showEntryDeleteAlert: Bool = false

    private let dataToUpdate: [ObjectEntities] = [
        .products,
        .product_groups,
        .quantity_units,
        .quantity_unit_conversions,
        .shopping_lists,
        .shopping_list,
    ]
    func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate)
    }

    func checkBelowStock(item: ShoppingListItem) -> Bool {
        if let product = mdProducts.first(where: { $0.id == item.productID }) {
            if product.minStockAmount > item.amount {
                return true
            }
        }
        return false
    }

    private func changeDoneStatus(shoppingListItem: ShoppingListItem) async {
        shoppingListItem.done = shoppingListItem.done == 1 ? 0 : 1
        do {
            try shoppingListItem.modelContext?.save()
            try await grocyVM.putMDObjectWithID(object: .shopping_list, id: shoppingListItem.id, content: shoppingListItem)
            GrocyLogger.info("Done status changed successfully.")
            await grocyVM.requestData(objects: [.shopping_list])
        } catch {
            GrocyLogger.error("Shopping list done status change failed. \(error)")
        }
    }

    private func deleteItem(itemToDelete: ShoppingListItem) {
        shlItemToDelete = itemToDelete
        showEntryDeleteAlert.toggle()
    }

    private func deleteSHLItem(item: ShoppingListItem) async {
        do {
            try await grocyVM.deleteMDObject(object: .shopping_list, id: item.id)
            item.modelContext?.delete(item)
            GrocyLogger.info("Deleting shopping list item was successful.")
            await grocyVM.requestData(objects: [.shopping_list])
        } catch {
            GrocyLogger.error("Deleting shopping list item failed. \(error)")
        }
    }

    var selectedShoppingList: ShoppingListDescription? {
        shoppingListDescriptions
            .filter {
                $0.id == selectedShoppingListID
            }
            .first
    }

    var selectedShoppingListItems: [ShoppingListItem] {
        shoppingList
            .filter {
                $0.shoppingListID == selectedShoppingListID
            }
    }

    var filteredShoppingListItems: [ShoppingListItem] {
        selectedShoppingListItems
            .filter { shLItem in
                switch filteredStatus {
                case .all:
                    return true
                case .belowMinStock:
                    return checkBelowStock(item: shLItem)
                case .done:
                    return shLItem.done == 1
                case .undone:
                    return shLItem.done == 0
                }
            }
            .filter { shLItem in
                if !searchString.isEmpty {
                    if let product = mdProducts.first(where: { $0.id == shLItem.productID }) {
                        return product.name.localizedCaseInsensitiveContains(searchString)
                    } else {
                        return false
                    }
                } else {
                    return true
                }
            }
    }

    var groupedShoppingList: [String: [ShoppingListItemWrapped]] {
        var dict: [String: [ShoppingListItemWrapped]] = [:]
        for listItem in filteredShoppingListItems {
            let product = mdProducts.first(where: { $0.id == listItem.productID })
            switch shoppingListGrouping {
            case .productGroup:
                let productGroup = mdProductGroups.first(where: { $0.id == product?.productGroupID })
                if dict[productGroup?.name ?? ""] == nil {
                    dict[productGroup?.name ?? ""] = []
                }
                dict[productGroup?.name ?? ""]?.append(
                    ShoppingListItemWrapped(shoppingListItem: listItem, product: product)
                )
            case .defaultStore:
                let store = mdStores.first(where: { $0.id == product?.storeID })
                if dict[store?.name ?? ""] == nil {
                    dict[store?.name ?? ""] = []
                }
                dict[store?.name ?? ""]?.append(
                    ShoppingListItemWrapped(shoppingListItem: listItem, product: product)
                )
            default:
                if dict[""] == nil {
                    dict[""] = []
                }
                dict[""]?.append(
                    ShoppingListItemWrapped(shoppingListItem: listItem, product: product)
                )
            }
        }
        return dict
    }

    var numBelowStock: Int {
        selectedShoppingListItems
            .filter { shLItem in
                checkBelowStock(item: shLItem)
            }
            .count
    }

    var numUndone: Int {
        selectedShoppingListItems
            .filter { shLItem in
                shLItem.done == 0
            }
            .count
    }

    var numDone: Int {
        selectedShoppingListItems
            .filter { shLItem in
                shLItem.done == 1
            }
            .count
    }

    func deleteShoppingList() async {
        do {
            try await grocyVM.deleteMDObject(object: .shopping_lists, id: selectedShoppingListID)
            GrocyLogger.info("Deleting shopping list was successful.")
            await grocyVM.requestData(objects: [.shopping_lists])
        } catch {
            GrocyLogger.error("Deleting shopping list failed. \(error)")
        }
    }

    private func slAction(_ actionType: ShoppingListActionType) async {
        do {
            if actionType == .clearDone {
                // this is not clean, but was the fastest way to work around the different data types
                let jsonContent = try! JSONEncoder().encode(ShoppingListClearAction(listID: selectedShoppingListID, doneOnly: true))
                try await grocyVM.grocyApi.shoppingListAction(content: jsonContent, actionType: actionType)
            } else {
                try await grocyVM.shoppingListAction(content: ShoppingListAction(listID: selectedShoppingListID), actionType: actionType)
            }
            GrocyLogger.info("SHLAction \(actionType) successful.")
            await grocyVM.requestData(objects: [.shopping_list])
        } catch {
            GrocyLogger.error("SHLAction failed. \(error)")
        }
    }

    var body: some View {
        List {
            if grocyVM.failedToLoadObjects.filter({ dataToUpdate.contains($0) }).count > 0 {
                ServerProblemView()
            } else if filteredShoppingListItems.isEmpty {
                ContentUnavailableView("Shopping list is empty.", systemImage: MySymbols.shoppingList)
            }
            Section {
                if numBelowStock > 0 || numDone > 0 || numUndone > 0 {
                    ShoppingListFilterActionView(
                        filteredStatus: $filteredStatus,
                        numBelowStock: numBelowStock,
                        numDone: numDone,
                        numUndone: numUndone
                    )
                    .listRowInsets(EdgeInsets())
                }
            }
            ForEach(groupedShoppingList.sorted(by: { $0.key < $1.key }), id: \.key) { groupName, groupElements in
                #if os(macOS)
                    DisclosureGroup(
                        isExpanded: Binding.constant(true),
                        content: {
                            ForEach(
                                groupElements.sorted(using: sortSetting),
                                id: \.shoppingListItem.id,
                                content: { element in
                                    shoppingListRowWithNavigation(element: element)
                                }
                            )
                        },
                        label: {
                            if shoppingListGrouping == .productGroup, groupName.isEmpty {
                                Text("Ungrouped").italic()
                            } else if shoppingListGrouping == .none {
                                EmptyView()
                            } else {
                                Text(groupName).bold()
                            }
                        }
                    )
                #else
                    Section(
                        content: {
                            ForEach(
                                groupElements.sorted(using: sortSetting),
                                id: \.shoppingListItem.id,
                                content: { element in
                                    shoppingListRowWithNavigation(element: element)
                                }
                            )
                        },
                        header: {
                            if shoppingListGrouping == .productGroup, groupName.isEmpty {
                                Text("Ungrouped")
                                    .italic()
                            } else if shoppingListGrouping == .none {
                                EmptyView()
                            } else {
                                Text(groupName).bold()
                            }
                        }
                    )
                #endif
            }
        }
        .navigationTitle(selectedShoppingList?.name ?? "Shopping list")
        .toolbar {
            ToolbarItemGroup(
                placement: .navigation,
                content: {
                    Button(action: { showFilterSheet = true }) {
                        Label("Filter", systemImage: MySymbols.filter)
                    }
                    sortGroupMenu
                }
            )
            ToolbarTitleMenu {
                shoppingListActionContent
                Divider()
                shoppingListItemActionContent
            }
            ToolbarItem(
                placement: .primaryAction,
                content: {
                    Button(
                        "Add item",
                        systemImage: MySymbols.new,
                        action: {
                            shoppingListInteractionRouter.present(.newShoppingListEntry)
                        }
                    )
                    .help("Add item")
                }
            )
        }
        .navigationDestination(
            for: ShoppingListDescription.self,
            destination: { desc in
                ShoppingListFormView(shoppingListDescription: desc)
            }
        )
        .navigationDestination(
            for: ShoppingListItem.self,
            destination: { item in
                ShoppingListEntryFormView(existingShoppingListEntry: item)
            }
        )
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if firstAppear {
                await updateData()
                if selectedShoppingListID == -1 {
                    selectedShoppingListID = shoppingListDescriptions.first?.id ?? -1
                }
                firstAppear = false
            }
        }
        .searchable(
            text: $searchString,
            prompt: "Search"
        )
        .refreshable {
            await updateData()
        }
        .animation(.default, value: groupedShoppingList.count)
        .sheet(isPresented: $showFilterSheet) {
            NavigationStack {
                ShoppingListFilterView(filteredStatus: $filteredStatus)
                    .navigationTitle("Filter")
                    #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(
                            placement: .confirmationAction,
                            content: {
                                Button(
                                    role: .confirm,
                                    action: {
                                        showFilterSheet = false
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
                                        filteredStatus = .all
                                        showFilterSheet = false
                                    }
                                )
                            }
                        )
                    }
            }
            .presentationDetents([.medium])
        }
        .environment(shoppingListInteractionRouter)
        .sheet(item: $shoppingListInteractionRouter.presentedInteraction) { interaction in
            NavigationStack {
                switch interaction {
                case .newShoppingList:
                    ShoppingListFormView()
                case .newShoppingListEntry:
                    ShoppingListEntryFormView(selectedShoppingListID: selectedShoppingListID, isPopup: true)
                case .purchase(let item):
                    PurchaseProductView(directProductToPurchaseID: item.productID, productToPurchaseAmount: item.amount, isPopup: true)
                case .autoPurchase(let item):
                    PurchaseProductView(directProductToPurchaseID: item.productID, productToPurchaseAmount: item.amount, autoPurchase: true, isPopup: true)
                }
            }
        }
        .alert(
            "Do you really want to delete this item?",
            isPresented: $showEntryDeleteAlert,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let item = shlItemToDelete {
                        Task {
                            await deleteSHLItem(item: item)
                        }
                    }
                }
            },
            message: {
                if let item = shlItemToDelete {
                    Text(mdProducts.first(where: { $0.id == item.productID })?.name ?? "Name not found")
                }
            }
        )
        .alert(
            "Do you really want to delete this shopping list?",
            isPresented: $showSHLDeleteAlert,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteShoppingList()
                    }
                }
            },
            message: { Text(shoppingListDescriptions.first(where: { $0.id == selectedShoppingListID })?.name ?? "Name not found") }
        )
        .alert(
            "Do your really want to clear this shopping list?",
            isPresented: $showClearListAlert,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Confirm", role: .destructive) {
                    Task {
                        await slAction(.clear)
                    }
                }
            },
            message: { Text(shoppingListDescriptions.first(where: { $0.id == selectedShoppingListID })?.name ?? "Name not found") }
        )
        .alert(
            "Do you really want to clear all done items?",
            isPresented: $showClearDoneAlert,
            actions: {
                Button("Cancel", role: .cancel) {}
                Button("Confirm", role: .destructive) {
                    Task {
                        await slAction(.clearDone)
                    }
                }
            },
            message: { Text(shoppingListDescriptions.first(where: { $0.id == selectedShoppingListID })?.name ?? "Name not found") }
        )
    }

    var shoppingListActionContent: some View {
        Group {
            Picker(
                selection: $selectedShoppingListID,
                label: Text(""),
                content: {
                    ForEach(shoppingListDescriptions, id: \.id) { shoppingListDescription in
                        Text(shoppingListDescription.name).tag(shoppingListDescription.id)
                    }
                }
            )
            .help("Shopping list")
            Divider()
            Button(
                action: {
                    shoppingListInteractionRouter.present(.newShoppingList)
                },
                label: {
                    Label("New shopping list", systemImage: MySymbols.new)
                }
            )
            .help("New shopping list")
            NavigationLink(
                value: selectedShoppingList,
                label: {
                    Label("Edit shopping list", systemImage: MySymbols.edit)
                }
            )
            .help("Edit shopping list")
            Button(
                role: .destructive,
                action: {
                    showSHLDeleteAlert.toggle()
                },
                label: {
                    Label("Delete shopping list", systemImage: MySymbols.delete)
                }
            )
            .help("Delete shopping list")
        }
    }

    var shoppingListItemActionContent: some View {
        Group {
            Button(
                role: .destructive,
                action: {
                    showClearListAlert.toggle()
                },
                label: {
                    Label("Clear list", systemImage: MySymbols.clear)
                }
            )
            .help("Clear list")
            //            Button(action: {
            //                print("Not implemented")
            //            }, label: {
            //                Label("Add all list items to stock", systemImage: "questionmark")
            //            })
            //            .help("Add all list items to stock")
            //                .disabled(true)
            Button(
                role: .destructive,
                action: {
                    showClearDoneAlert.toggle()
                },
                label: {
                    Label("Clear done items", systemImage: MySymbols.done)
                }
            )
            .help("Clear done items")
            Button(
                action: {
                    Task {
                        await slAction(.addMissing)
                    }
                },
                label: {
                    Label("Add products that are below defined min. stock amount", systemImage: MySymbols.addToShoppingList)
                }
            )
            .help("Add products that are below defined min. stock amount")
            Button(
                action: {
                    Task {
                        await slAction(.addExpired)
                        await slAction(.addOverdue)
                    }
                },
                label: {
                    Label("Add overdue/expired products", systemImage: MySymbols.addToShoppingList)
                }
            )
            .help("Add overdue/expired products")
        }
    }

    var sortGroupMenu: some View {
        Menu(
            content: {
                Picker(
                    "Group by",
                    systemImage: MySymbols.groupBy,
                    selection: $shoppingListGrouping,
                    content: {
                        Label("None", systemImage: MySymbols.product)
                            .labelStyle(.titleAndIcon)
                            .tag(ShoppingListGrouping.none)
                        Label("Product group", systemImage: MySymbols.amount)
                            .labelStyle(.titleAndIcon)
                            .tag(ShoppingListGrouping.productGroup)
                        Label("Store", systemImage: MySymbols.amount)
                            .labelStyle(.titleAndIcon)
                            .tag(ShoppingListGrouping.defaultStore)
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
                                .tag([KeyPathComparator(\ShoppingListItemWrapped.product?.name, order: .forward)])
                            Label("Amount", systemImage: MySymbols.amount)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\ShoppingListItemWrapped.shoppingListItem.amount, order: .forward)])
                        } else {
                            Label("Name", systemImage: MySymbols.product)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\ShoppingListItemWrapped.product?.name, order: .reverse)])
                            Label("Amount", systemImage: MySymbols.amount)
                                .labelStyle(.titleAndIcon)
                                .tag([KeyPathComparator(\ShoppingListItemWrapped.shoppingListItem.amount, order: .reverse)])
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
                    systemImage: MySymbols.sortCategory,
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

    @ViewBuilder
    private func shoppingListRowWithNavigation(element: ShoppingListItemWrapped) -> some View {
        NavigationLink(
            value: element.shoppingListItem,
            label: {
                ShoppingListRowView(
                    shoppingListItem: element.shoppingListItem,
                    isBelowStock: checkBelowStock(item: element.shoppingListItem),
                    product: element.product,
                    quantityUnit: mdQuantityUnits.first(where: { $0.id == element.product?.quIDPurchase }),
                    quantityUnitConversions: mdQuantityUnitConversions.filter { $0.toQuID == element.shoppingListItem.quID },
                    userSettings: userSettings,
                    onToggleDone: changeDoneStatus,
                    onDelete: deleteItem
                )
            }
        )
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        ShoppingListView()
    }
}
