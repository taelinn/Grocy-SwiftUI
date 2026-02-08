//
//  BBBarcodeListView.swift
//  Grocy Mobile
//
//  Barcode list view
//

import SwiftUI
import SwiftData

struct BBBarcodeListView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Query var userSettingsList: GrocyUserSettingsList
    @Bindable var viewModel: BarcodeBuddyViewModel
    
    enum ActiveSheet: Identifiable {
        case detail(BBUnknownBarcode)
        case productPicker(BBUnknownBarcode)
        case productForm(BBUnknownBarcode)
        case stockActionChoice(BBUnknownBarcode, productID: Int)
        case purchase(BBUnknownBarcode, productID: Int)
        case consume(BBUnknownBarcode, productID: Int)
        
        var id: String {
            switch self {
            case .detail(let barcode): return "detail-\(barcode.id)"
            case .productPicker(let barcode): return "picker-\(barcode.id)"
            case .productForm(let barcode): return "form-\(barcode.id)"
            case .stockActionChoice(let barcode, _): return "choice-\(barcode.id)"
            case .purchase(let barcode, _): return "purchase-\(barcode.id)"
            case .consume(let barcode, _): return "consume-\(barcode.id)"
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet?
    @State private var createdProductID: Int?
    
    private var userSettings: GrocyUserSettings? {
        userSettingsList.first
    }
    
    var body: some View {
        Group {
            if viewModel.unknownBarcodes.isEmpty && !viewModel.isLoading {
                ContentUnavailableView {
                    Label("All Clear!", systemImage: "checkmark.circle")
                } description: {
                    Text("No unresolved barcodes")
                }
            } else {
                List {
                    // New Barcodes (looked up)
                    if !viewModel.newBarcodes.isEmpty {
                        Section {
                            ForEach(viewModel.newBarcodes) { barcode in
                                BBBarcodeRowView(barcode: barcode)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        activeSheet = .detail(barcode)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            Task {
                                                await deleteBarcode(barcode)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            HStack {
                                Text("New Barcodes")
                                Spacer()
                                Text("\(viewModel.newBarcodes.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Unknown Barcodes (not looked up)
                    if !viewModel.trulyUnknownBarcodes.isEmpty {
                        Section {
                            ForEach(viewModel.trulyUnknownBarcodes) { barcode in
                                BBBarcodeRowView(barcode: barcode)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        activeSheet = .detail(barcode)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            Task {
                                                await deleteBarcode(barcode)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            HStack {
                                Text("Unknown Barcodes")
                                Spacer()
                                Text("\(viewModel.trulyUnknownBarcodes.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .detail(let barcode):
                BBBarcodeDetailSheet(
                    barcode: barcode,
                    onMatchToProduct: {
                        activeSheet = .productPicker(barcode)
                    },
                    onCreateProduct: {
                        activeSheet = .productForm(barcode)
                    },
                    onDismiss: {
                        await deleteBarcode(barcode)
                    }
                )
                
            case .productPicker(let barcode):
                ProductPickerView { product in
                    Task {
                        await associateBarcode(barcode, withProductID: product.id)
                    }
                }
                
            case .productForm(let barcode):
                NavigationStack {
                    MDProductFormView(
                        userSettings: userSettings,
                        queuedBarcode: barcode.barcode,
                        createBarcode: true,
                        createdProductID: $createdProductID,
                        initialName: barcode.name
                    )
                    .onChange(of: createdProductID) { oldValue, newValue in
                        if let productID = newValue {
                            // Product was created, now associate it with the barcode
                            Task {
                                await associateBarcode(barcode, withProductID: productID)
                            }
                        }
                    }
                }
                
            case .stockActionChoice(let barcode, let productID):
                BBStockActionSheet(
                    barcode: barcode,
                    productID: productID,
                    onAddToStock: {
                        activeSheet = .purchase(barcode, productID: productID)
                    },
                    onConsumeFromStock: {
                        activeSheet = .consume(barcode, productID: productID)
                    },
                    onSkip: {
                        Task {
                            await completeBarcode(barcode)
                        }
                    }
                )
                
            case .purchase(let barcode, let productID):
                PurchaseProductView(
                    directProductToPurchaseID: productID,
                    productToPurchaseAmount: Double(barcode.amount)
                )
                .onDisappear {
                    Task {
                        await completeBarcode(barcode)
                    }
                }
                
            case .consume(let barcode, let productID):
                ConsumeProductView(
                    directProductToConsumeID: productID
                )
                .onDisappear {
                    Task {
                        await completeBarcode(barcode)
                    }
                }
            }
        }
    }
    
    private func deleteBarcode(_ barcode: BBUnknownBarcode) async {
        _ = await viewModel.deleteBarcode(id: barcode.id)
    }
    
    private func associateBarcode(_ barcode: BBUnknownBarcode, withProductID productID: Int) async {
        let success = await viewModel.associateBarcode(id: barcode.id, productId: productID)
        if success {
            // Move to stock action choice instead of dismissing
            activeSheet = .stockActionChoice(barcode, productID: productID)
        }
    }
    
    private func completeBarcode(_ barcode: BBUnknownBarcode) async {
        // Delete the barcode from BarcodeBuddy
        await deleteBarcode(barcode)
        // Close the sheet
        activeSheet = nil
        // Refresh the list
        await viewModel.fetchUnknownBarcodes()
    }
}
