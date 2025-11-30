//
//  StockTableRow.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 28.12.20.
//

import SwiftData
import SwiftUI

struct StockTableRow: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("localizationKey") var localizationKey: String = "en"

    #if os(iOS)
        @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
        @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    #endif

    // Pass data from parent to avoid duplicate queries
    let mdQuantityUnits: MDQuantityUnits
    let shoppingList: [ShoppingListItem]
    let mdProductGroups: MDProductGroups
    let volatileStock: VolatileStock?
    let userSettings: GrocyUserSettings?

    var stockElement: StockElement

    @State private var showDetailView: Bool = false

    var quantityUnit: MDQuantityUnit? {
        mdQuantityUnits.first(where: { $0.id == stockElement.product?.quIDStock })
    }

    var backgroundColor: Color {
        let productID = stockElement.productID

        if (volatileStock?.dueProducts ?? []).contains(where: { $0.productID == productID }) {
            return Color(.GrocyColors.grocyYellowBackground)
        }
        if (volatileStock?.expiredProducts ?? []).contains(where: { $0.productID == productID }) {
            return Color(.GrocyColors.grocyRedBackground)
        }
        if (volatileStock?.overdueProducts ?? []).contains(where: { $0.productID == productID }) {
            return Color(.GrocyColors.grocyGrayBackground)
        }
        if (volatileStock?.missingProducts ?? []).contains(where: { $0.productID == productID }) {
            return Color(.GrocyColors.grocyBlueBackground)
        }

        #if os(iOS)
            return colorScheme == .light ? Color.white : Color.black
        #elseif os(macOS)
            return colorScheme == .light ? Color.white : Color.gray.opacity(0.05)
        #endif
    }

    var body: some View {
        NavigationLink(
            value: stockElement,
            label: {
                content
            }
        )
        .contextMenu(menuItems: {
            StockTableMenuEntriesView(stockElement: stockElement, mdQuantityUnits: mdQuantityUnits)
        })
        .swipeActions(
            edge: .leading,
            allowsFullSwipe: true,
            content: {
                if stockElement.amount > 0 {
                    StockTableRowActionsView(stockElement: stockElement, shownActions: [.consumeQA], mdQuantityUnits: mdQuantityUnits)
                }
                if (stockElement.amount - stockElement.amountOpened) > 0 {
                    StockTableRowActionsView(stockElement: stockElement, shownActions: [.openQA], mdQuantityUnits: mdQuantityUnits)
                }
            }
        )
        .swipeActions(
            edge: .trailing,
            allowsFullSwipe: true,
            content: {
                if stockElement.amount > 0 {
                    StockTableRowActionsView(stockElement: stockElement, shownActions: [.consumeAll], mdQuantityUnits: mdQuantityUnits)
                }
            }
        )
        #if os(macOS)
            .listRowBackground(backgroundColor.clipped().cornerRadius(5))
            .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
        #else
            .listRowBackground(backgroundColor)
        #endif
    }

    var content: some View {
        #if os(iOS)
            Group {
                if horizontalSizeClass == .compact && verticalSizeClass == .regular {
                    HStack {
                        VStack(alignment: .leading) {
                            stockElementNameAndActions
                            stockElementDetails
                        }
                        Spacer()
                    }
                } else {
                    HStack {
                        stockElementNameAndActions
                        stockElementDetails
                        Spacer()
                    }
                }
            }
        #elseif os(macOS)
            HStack {
                stockElementNameAndActions
                stockElementDetails
                Spacer()
            }
        #endif
    }

    var stockElementNameAndActions: some View {
        Text(stockElement.product?.name ?? "")
            .font(.headline)
    }

    var stockElementDetails: some View {
        VStack(alignment: .leading) {
            if let productGroup = mdProductGroups.first(where: { $0.id == stockElement.product?.productGroupID }) {
                Text(productGroup.name)
                    .font(.caption)
            } else {
                Text("")
            }

            HStack {
                Text("\(stockElement.amount.formattedAmount) \(quantityUnit?.getName(amount: stockElement.amount) ?? "")")
                if stockElement.amountOpened > 0 {
                    Text("\(stockElement.amountOpened.formattedAmount) opened")
                        .font(.caption)
                        .italic()
                }
                if stockElement.amount != stockElement.amountAggregated {
                    Text("Σ \(stockElement.amountAggregated.formattedAmount) \(quantityUnit?.getName(amount: stockElement.amountAggregated) ?? "")")
                        .foregroundStyle(Color(.GrocyColors.grocyGray))
                    if stockElement.amountOpenedAggregated > 0 {
                        Text("\(stockElement.amountOpenedAggregated.formattedAmount) opened")
                            .foregroundStyle(Color(.GrocyColors.grocyGray))
                            .font(.caption)
                            .italic()
                    }
                }
                if userSettings?.showIconOnStockOverviewPageWhenProductIsOnShoppingList ?? true,
                    shoppingList.first(where: { $0.productID == stockElement.productID }) != nil
                {
                    Image(systemName: MySymbols.shoppingList)
                        .foregroundStyle(Color(.GrocyColors.grocyGray))
                        .help("This product is currently on a shopping list.")
                }
            }
            if let dueDate = stockElement.bestBeforeDate {
                HStack {
                    if dueDate == getNeverOverdueDate() {
                        Text("Never overdue")
                    } else {
                        Text(formatDateAsString(dueDate, showTime: false, localizationKey: localizationKey) ?? "")
                        Text(getRelativeDateAsText(dueDate, localizationKey: localizationKey) ?? "")
                            .font(.caption)
                            .italic()
                    }
                }
            }
        }
    }
}

//struct StockTableRow_Previews: PreviewProvider {
//    static var previews: some View {
//        StockTableRow(stockElement: StockElement(amount: "2", amountAggregated: "5", value: "1.0", bestBeforeDate: "12.12.2021", amountOpened: "1", amountOpenedAggregated: "2", isAggregatedAmount: "0", dueType: "1", productID: "1", product: MDProduct(id: "1", name: "Product", mdProductDescription: "", productGroupID: "1", active: "1", locationID: "1", storeID: "1", quIDPurchase: "1", quIDStock: "1", minStockAmount: "0", defaultBestBeforeDays: "0", defaultBestBeforeDaysAfterOpen: "0", defaultBestBeforeDaysAfterFreezing: "0", defaultBestBeforeDaysAfterThawing: "0", pictureFileName: nil, enableTareWeightHandling: "0", tareWeight: "0", notCheckStockFulfillmentForRecipes: "0", parentProductID: nil, calories: "13", cumulateMinStockAmountOfSubProducts: "1", dueType: "1", quickConsumeAmount: "1", rowCreatedTimestamp: "ts", hideOnStockOverview: nil, userfields: nil)), activeSheet: Binding.constant(nil))
//    }
//}
