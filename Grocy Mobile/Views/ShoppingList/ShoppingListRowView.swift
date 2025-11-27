//
//  ShoppingListRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 13.09.25.
//

import SwiftData
import SwiftUI

struct ShoppingListRowView: View {
    @Environment(\.colorScheme) var colorScheme

    var shoppingListItem: ShoppingListItem
    var isBelowStock: Bool
    var product: MDProduct? = nil
    var quantityUnit: MDQuantityUnit? = nil
    var quantityUnitConversions: MDQuantityUnitConversions = []

    // Callbacks for interactions
    var onToggleDone: (ShoppingListItem) async -> Void = { _ in }
    var onDelete: (ShoppingListItem) -> Void = { _ in }
    var onShowPurchase: (ShoppingListItem) -> Void = { _ in }
    var onShowAutoPurchase: (ShoppingListItem) -> Void = { _ in }
    var onEditItem: (ShoppingListItem) -> Void = { _ in }

    private var factoredAmount: Double {
        shoppingListItem.amount * (quantityUnitConversions.first(where: { $0.fromQuID == shoppingListItem.quID })?.factor ?? 1)
    }

    var amountString: String {
        if let quantityUnit = quantityUnit {
            return "\(factoredAmount.formattedAmount) \(quantityUnit.getName(amount: factoredAmount))"
        } else {
            return "\(factoredAmount.formattedAmount)"
        }
    }

    private var backgroundColor: Color {
        if isBelowStock {
            return Color(.GrocyColors.grocyBlueBackground)
        } else if shoppingListItem.done == 1 {
            return Color(.GrocyColors.grocyGreen).opacity(0.3)
        } else {
            return Color(.GrocyColors.grocyGrayBackground)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(product?.name ?? shoppingListItem.note)
                .font(.headline)
                .strikethrough(shoppingListItem.done == 1)
            Text("\(Text("Amount")): \(amountString)")
                .strikethrough(shoppingListItem.done == 1)
        }
        .foregroundStyle(shoppingListItem.done == 1 ? Color.gray : Color.primary)
        .listRowBackground(backgroundColor)
        .swipeActions(
            edge: .trailing,
            allowsFullSwipe: true,
            content: {
                Button(
                    role: .destructive,
                    action: { onDelete(shoppingListItem) },
                    label: { Label("Delete", systemImage: MySymbols.delete) }
                )
            }
        )
        .swipeActions(
            edge: .leading,
            allowsFullSwipe: shoppingListItem.done != 1,
            content: {
                Group {
                    Button(
                        action: {
                            Task {
                                await onToggleDone(shoppingListItem)
                            }
                        },
                        label: { Label("Done", systemImage: MySymbols.done) }
                    )
                    .tint(.green)
                    .accessibilityHint("Mark this item as done")
                    if shoppingListItem.productID != nil {
                        Button(
                            action: {
                                onShowPurchase(shoppingListItem)
                            },
                            label: { Label("Purchase", systemImage: "shippingbox") }
                        )
                        .tint(.blue)
                    }
                }
            }
        )
    }
}

#Preview {
    List {
        ShoppingListRowView(
            shoppingListItem: ShoppingListItem(id: 1, productID: 1, note: "note", amount: 2, shoppingListID: 1, done: 1, quID: 1, rowCreatedTimestamp: "ts"),
            isBelowStock: false
        )
        ShoppingListRowView(
            shoppingListItem: ShoppingListItem(id: 2, productID: 1, note: "note", amount: 2, shoppingListID: 1, done: 0, quID: 1, rowCreatedTimestamp: "ts"),
            isBelowStock: true
        )
    }
}
