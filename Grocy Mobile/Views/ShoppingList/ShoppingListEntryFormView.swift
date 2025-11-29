//
//  ShoppingListEntryFormView.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 02.12.20.
//

import OSLog
import SwiftData
import SwiftUI

struct ShoppingListEntryFormView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.dismiss) var dismiss

    @Query(sort: \MDProduct.name, order: .forward) var mdProducts: MDProducts
    @Query(sort: \MDQuantityUnit.id, order: .forward) var mdQuantityUnits: MDQuantityUnits
    @Query(sort: \ShoppingListDescription.id, order: .forward) var shoppingListDescriptions: ShoppingListDescriptions

    @State private var isProcessing: Bool = false
    @State private var isSuccessful: Bool? = nil
    @State private var errorMessage: String? = nil

    var existingShoppingListEntry: ShoppingListItem?
    @State private var shoppingListEntry: ShoppingListItem

    var selectedShoppingListID: Int?
    var productIDToSelect: Int?
    var isPopup: Bool = false

    var isFormValid: Bool {
        shoppingListEntry.amount > 0 && (shoppingListEntry.productID != nil || !shoppingListEntry.note.isEmpty)
    }

    var product: MDProduct? {
        mdProducts.first(where: { $0.id == shoppingListEntry.productID })
    }

    init(existingShoppingListEntry: ShoppingListItem? = nil, selectedShoppingListID: Int? = nil, productIDToSelect: Int? = nil, isPopup: Bool = false) {
        self.existingShoppingListEntry = existingShoppingListEntry
        self.selectedShoppingListID = selectedShoppingListID
        self.productIDToSelect = productIDToSelect
        _shoppingListEntry = State(initialValue: existingShoppingListEntry ?? ShoppingListItem())
    }

    private func getQuantityUnit() -> MDQuantityUnit? {
        let quIDP = mdProducts.first(where: { $0.id == shoppingListEntry.productID })?.quIDPurchase
        let qu = mdQuantityUnits.first(where: { $0.id == quIDP })
        return qu
    }

    private var currentQuantityUnit: MDQuantityUnit? {
        let quIDP = mdProducts.first(where: { $0.id == shoppingListEntry.productID })?.quIDPurchase
        return mdQuantityUnits.first(where: { $0.id == quIDP })
    }

    private func updateData() async {
        await grocyVM.requestData(objects: [.shopping_list])
    }

    private func finishForm() {
        #if os(iOS)
            dismiss()
        #elseif os(macOS)
            NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
        #endif
    }

    private func saveShoppingListEntry() async {
        if shoppingListEntry.id == -1 {
            shoppingListEntry.id = grocyVM.findNextID(.shopping_list)
        }
        isProcessing = true
        isSuccessful = nil
        do {
            try shoppingListEntry.modelContext?.save()
            if existingShoppingListEntry == nil {
                _ = try await grocyVM.postMDObject(object: .shopping_list, content: shoppingListEntry)
            } else {
                try await grocyVM.putMDObjectWithID(object: .shopping_list, id: shoppingListEntry.id, content: shoppingListEntry)
            }
            GrocyLogger.info("Shopping list entry saved successfully.")
            await updateData()
            isSuccessful = true
        } catch {
            GrocyLogger.error("Shopping entry failed. \(error)")
            errorMessage = error.localizedDescription
            isSuccessful = false
        }
        isProcessing = false
    }

    var body: some View {
        Form {
            #if os(macOS)
                Text(existingShoppingListEntry == nil ? "Create shopping list item" : "Edit shopping list item").font(.headline)
            #endif
            Picker(
                selection: $shoppingListEntry.shoppingListID,
                label: Label("Shopping list", systemImage: MySymbols.shoppingList),
                content: {
                    ForEach(shoppingListDescriptions, id: \.id) { shLDescription in
                        Text(shLDescription.name).tag(shLDescription.id)
                    }
                }
            )
            .foregroundStyle(.primary)

            ProductField(productID: $shoppingListEntry.productID, description: "Product")
                .onChange(of: shoppingListEntry.productID) {
                    if let selectedProduct = mdProducts.first(where: { $0.id == shoppingListEntry.productID }) {
                        shoppingListEntry.quID = selectedProduct.quIDPurchase
                    }
                }

            AmountSelectionView(productID: $shoppingListEntry.productID, amount: $shoppingListEntry.amount, quantityUnitID: $shoppingListEntry.quID)

            Section(
                header: Label("Note", systemImage: "square.and.pencil")
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
            ) {
                TextEditor(text: $shoppingListEntry.note)
                    .frame(height: 50)
            }
            #if os(macOS)
                HStack {
                    Button("Cancel") {
                        finishForm()
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Save") {
                        Task {
                            await saveShoppingListEntry()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
            #endif
        }
        .navigationTitle(existingShoppingListEntry == nil ? "Create shopping list item" : "Edit shopping list item")
        .task {
            await updateData()
        }
        .toolbar {
            if isPopup {
                ToolbarItem(
                    placement: .cancellationAction,
                    content: {
                        Button(
                            role: .cancel,
                            action: {
                                finishForm()
                            }
                        )
                        .keyboardShortcut(.cancelAction)
                    }
                )
            }
            ToolbarItem(
                placement: .confirmationAction,
                content: {
                    Button(
                        role: .confirm,
                        action: {
                            Task {
                                await saveShoppingListEntry()
                            }
                        }
                    )
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isFormValid)
                }
            )
        }
        .onChange(of: isSuccessful) {
            if isSuccessful == true {
                finishForm()
            }
        }
        .sensoryFeedback(.success, trigger: isSuccessful == true)
        .sensoryFeedback(.error, trigger: isSuccessful == false)
    }
}

#Preview("Create", traits: .previewData) {
    NavigationStack {
        ShoppingListEntryFormView()
    }
}

#Preview("Edit", traits: .previewData) {
    NavigationStack {
        ShoppingListEntryFormView(existingShoppingListEntry: ShoppingListItem(id: 1, amount: 1.0, shoppingListID: 1, done: 0, rowCreatedTimestamp: ""))
    }
}
