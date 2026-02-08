//
//  BBBarcodeDetailSheet.swift
//  Grocy Mobile
//
//  Barcode detail and action sheet
//

import SwiftUI

struct BBBarcodeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let barcode: BBUnknownBarcode
    let onMatchToProduct: () -> Void
    let onCreateProduct: () -> Void
    let onDismiss: () async -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var isDismissing = false
    
    var body: some View {
        NavigationStack {
            List {
                // Barcode Info Section
                Section {
                    LabeledContent("Barcode", value: barcode.barcode)
                    
                    if let name = barcode.name {
                        LabeledContent("Product Name", value: name)
                    }
                    
                    LabeledContent("Amount", value: "\(barcode.amount)")
                    
                    if let price = barcode.price {
                        LabeledContent("Price", value: price)
                    }
                    
                    if let days = barcode.bestBeforeInDays {
                        LabeledContent("Best Before", value: "\(days) days")
                    }
                    
                    LabeledContent("Status", value: barcode.isLookedUp ? "Looked Up" : "Unknown")
                } header: {
                    Text("Barcode Information")
                }
                
                // Alternative Names
                if let altNames = barcode.altNames, !altNames.isEmpty {
                    Section {
                        ForEach(altNames, id: \.self) { name in
                            Text(name)
                        }
                    } header: {
                        Text("Alternative Names")
                    }
                }
                
                // Actions Section
                Section {
                    Button {
                        dismiss()
                        onMatchToProduct()
                    } label: {
                        Label("Match to Product", systemImage: "link")
                    }
                    
                    Button {
                        dismiss()
                        onCreateProduct()
                    } label: {
                        Label("Create New Product", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Actions")
                }
                
                // Dismiss Section
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        if isDismissing {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Dismissing...")
                            }
                        } else {
                            Label("Dismiss Barcode", systemImage: "trash")
                        }
                    }
                    .disabled(isDismissing)
                }
            }
            .navigationTitle("Barcode Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Dismiss Barcode?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Dismiss", role: .destructive) {
                    Task {
                        isDismissing = true
                        await onDismiss()
                        isDismissing = false
                        dismiss()
                    }
                }
            } message: {
                Text("This barcode will be removed from the list. This action cannot be undone.")
            }
        }
    }
}
