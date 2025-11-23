//
//  QuickScanModeSelectProductView.swift
//  Grocy-SwiftUI (iOS)
//
//  Created by Georg Meissner on 21.01.21.
//

import SwiftData
import SwiftUI

struct QuickScanModeSelectProductView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @AppStorage("quickScanActionAfterAdd") private var quickScanActionAfterAdd: Bool = false
    @Query var userSettingsList: GrocyUserSettingsList
    var userSettings: GrocyUserSettings? {
        userSettingsList.first
    }

    @Environment(\.dismiss) var dismiss

    @State private var firstOpen: Bool = true

    var barcode: String?

    @State private var productID: Int?

    @Binding var qsActiveSheet: QSActiveSheet?
    @Binding var newRecognizedBarcode: MDProductBarcode?
    
    @State private var showProductForm: Bool = false

    private func resetForm() {
        productID = nil
    }

    private func updateData() async {
        await grocyVM.requestData(objects: [.product_barcodes])
    }

    private func finishForm() {
        dismiss()
    }

    private func addBarcodeForProduct() async {
        if let barcode = barcode,
            let productID = productID
        {
            let newBarcode = MDProductBarcode(
                id: grocyVM.findNextID(.product_barcodes),
                productID: productID,
                barcode: barcode,
                rowCreatedTimestamp: Date().iso8601withFractionalSeconds
            )
            do {
                _ = try await grocyVM.postMDObject(object: .product_barcodes, content: newBarcode)
                GrocyLogger.info("Add barcode successful.")
                await grocyVM.requestData(objects: [.product_barcodes])
                newRecognizedBarcode = newBarcode
                finishForm()
            } catch {
                GrocyLogger.error("Add barcode failed. \(error)")
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Text(barcode ?? "Barcode error").font(.title)
            }
            
            Section {
                ProductField(productID: $productID, description: "Product for this barcode")
                Button(action: {
                    showProductForm = true
                }, label: {
                    Label("Create product", systemImage: MySymbols.new)
                })
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Add barcode")
        .sheet(isPresented: $showProductForm) {
            NavigationStack {
                MDProductFormView(queuedBarcode: barcode)
            }
        }
        .toolbar(content: {
            ToolbarItem(
                placement: .cancellationAction,
                content: {
                    Button(role: .cancel) {
                        finishForm()
                    }
                    .keyboardShortcut(.cancelAction)
                }
            )
            ToolbarItem(
                placement: .automatic,
                content: {
                    Button(
                        role: .confirm,
                        action: { Task { await addBarcodeForProduct() } },
                    )
                    .disabled(productID == nil)
                    .keyboardShortcut(.defaultAction)
                }
            )
        })
    }
}

#Preview {
    QuickScanModeSelectProductView(
        barcode: "12345",
        qsActiveSheet: Binding.constant(QSActiveSheet.selectProduct),
        newRecognizedBarcode: Binding.constant(nil)
    )
}
