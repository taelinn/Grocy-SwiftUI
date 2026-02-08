//
//  QuickAddPurchaseSheet.swift
//  Grocy Mobile
//
//  Sheet for quickly adding a product to stock from favorites
//

import SwiftUI
import SwiftData

struct QuickAddPurchaseSheet: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.dismiss) private var dismiss
    
    @Query(filter: #Predicate<MDLocation> { $0.active }, sort: \MDLocation.name) private var mdLocations: [MDLocation]
    @Query(filter: #Predicate<MDQuantityUnit> { $0.active }, sort: \MDQuantityUnit.id) private var mdQuantityUnits: [MDQuantityUnit]
    @Query(sort: \MDQuantityUnitConversion.id) private var mdQuantityUnitConversions: [MDQuantityUnitConversion]
    
    let product: MDProduct
    let favorite: QuickAddFavorite
    
    @State private var amount: Double = 1.0
    @State private var locationID: Int
    @State private var quantityUnitID: Int
    @State private var note: String = ""
    @State private var noteRequired: Bool = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage: String?
    
    init(product: MDProduct, favorite: QuickAddFavorite) {
        self.product = product
        self.favorite = favorite
        _locationID = State(initialValue: product.locationID)
        _quantityUnitID = State(initialValue: product.quIDPurchase != -1 ? product.quIDPurchase : product.quIDStock)
    }
    
    private var currentQuantityUnit: MDQuantityUnit? {
        mdQuantityUnits.first(where: { $0.id == quantityUnitID })
    }
    
    private var stockQuantityUnit: MDQuantityUnit? {
        mdQuantityUnits.first(where: { $0.id == product.quIDStock })
    }
    
    private var quantityUnitConversions: [MDQuantityUnitConversion] {
        let quIDStock = product.quIDStock
        return mdQuantityUnitConversions.filter { $0.toQuID == quIDStock }
    }
    
    private var factoredAmount: Double {
        let quIDStock = product.quIDStock
        let conversion = quantityUnitConversions.first(where: { $0.fromQuID == quantityUnitID && $0.toQuID == quIDStock })
        return amount * (conversion?.factor ?? 1)
    }
    
    var body: some View {
        Form {
            productSection
            if noteRequired {
                noteSection
            }
            amountSection
            quantityUnitSection
            locationSection
            stockAmountSection
        }
        .navigationTitle("Quick Add")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    Task {
                        await addToStock()
                    }
                }
                .disabled(isProcessing || amount <= 0 || locationID == -1 || (noteRequired && note.isEmpty))
            }
        }
        .overlay {
            if isProcessing {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .task {
            // Check if product requires a note
            noteRequired = await grocyVM.isNoteRequired(for: product)
        }
    }
    
    private var productSection: some View {
        Section {
            HStack {
                Text("Product")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(product.name)
                    .fontWeight(.medium)
            }
        }
    }
    
    private var amountSection: some View {
        Section("Amount") {
            MyDoubleStepper(
                amount: $amount,
                description: "Amount",
                minAmount: 0.0001,
                amountStep: 1,
                amountName: currentQuantityUnit?.name ?? "",
                systemImage: MySymbols.amount
            )
        }
    }
    
    private var quantityUnitSection: some View {
        Section("Quantity Unit") {
            Picker(
                selection: $quantityUnitID,
                label: Label("Unit", systemImage: MySymbols.quantityUnit).foregroundStyle(.primary)
            ) {
                if let purchaseQU = mdQuantityUnits.first(where: { $0.id == product.quIDPurchase }) {
                    Text("\(purchaseQU.name) (Purchase QU)").tag(purchaseQU.id as Int)
                }
                if let stockQU = mdQuantityUnits.first(where: { $0.id == product.quIDStock }) {
                    Text("\(stockQU.name) (Stock QU)").tag(stockQU.id as Int)
                }
                ForEach(quantityUnitConversions, id: \.id) { conversion in
                    if let fromQU = mdQuantityUnits.first(where: { $0.id == conversion.fromQuID }) {
                        Text("\(fromQU.name)").tag(fromQU.id as Int)
                    }
                }
            }
        }
    }
    
    private var locationSection: some View {
        Section("Location") {
            Picker(
                selection: $locationID,
                label: Label("Location", systemImage: MySymbols.location).foregroundStyle(.primary)
            ) {
                ForEach(mdLocations, id: \.id) { location in
                    if location.id == product.locationID {
                        Text("\(location.name) (Default)").tag(location.id as Int)
                    } else {
                        Text(location.name).tag(location.id as Int)
                    }
                }
            }
        }
    }
    
    private var noteSection: some View {
        Section {
            TextField("What is it?", text: $note, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("Note")
        } footer: {
            Text("Describe what this is (e.g., 'Chicken Stir Fry'). This will be stored with the stock entry and used for label printing.")
        }
    }
    
    @ViewBuilder
    private var stockAmountSection: some View {
        if factoredAmount != amount {
            Section {
                HStack {
                    Text("Stock amount")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(factoredAmount.formattedAmount) \(stockQuantityUnit?.name ?? "")")
                }
            }
        }
    }
    
    private func addToStock() async {
        isProcessing = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Use product's default due date
        let dueDate: String
        if product.defaultDueDays == -1 {
            dueDate = "2999-12-31"
        } else {
            let dateComponents = DateComponents(day: product.defaultDueDays)
            let calculatedDate = Calendar.current.date(byAdding: dateComponents, to: Date()) ?? Date()
            dueDate = dateFormatter.string(from: calculatedDate)
        }
        
        let noteText = note.isEmpty ? nil : note
        let purchaseInfo = ProductBuy(
            amount: factoredAmount,
            bestBeforeDate: dueDate,
            transactionType: .purchase,
            price: nil,
            locationID: locationID,
            storeID: nil,
            note: noteText,
            stockLabelType: 2  // Automatically print label
        )
        
        do {
            try await grocyVM.postStockObject(id: product.id, stockModePost: .add, content: purchaseInfo)
            GrocyLogger.info("Quick Add: Added \(amount) \(currentQuantityUnit?.name ?? "") of \(product.name)")
            
            await grocyVM.requestData(additionalObjects: [.stock, .volatileStock])
            dismiss()
        } catch {
            GrocyLogger.error("Quick Add failed: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isProcessing = false
    }
}

// Preview requires MDProduct instance
