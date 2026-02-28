//
//  BBStockActionSheet.swift
//  Grocy Mobile
//
//  Stock action choice sheet for BarcodeBuddy workflow
//

import SwiftUI
import SwiftData

struct BBStockActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query var mdProducts: [MDProduct]
    
    let barcode: BBUnknownBarcode
    let productID: Int
    let onAddToStock: () -> Void
    let onConsumeFromStock: () -> Void
    let onSkip: () -> Void
    
    private var product: MDProduct? {
        mdProducts.first(where: { $0.id == productID })
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .padding(.top, 32)
                
                // Success message
                VStack(spacing: 8) {
                    Text("Product Linked Successfully")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let product {
                        Text(product.name)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Barcode info
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Barcode", systemImage: MySymbols.barcode)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(barcode.barcode)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Label("Scanned Amount", systemImage: "number")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(barcode.amount)")
                                .font(.headline)
                        }
                    }
                    .padding(4)
                }
                .padding(.horizontal)
                
                // Action question
                Text("What would you like to do with the \(barcode.amount) item(s)?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        dismiss()
                        onAddToStock()
                    }) {
                        Label("Add to Stock (\(barcode.amount))", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        dismiss()
                        onConsumeFromStock()
                    }) {
                        Label("Consume from Stock (\(barcode.amount))", systemImage: "minus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        dismiss()
                        onSkip()
                    }) {
                        Text("Skip - Just Link the Barcode")
                            .frame(maxWidth: .infinity)
                            .padding()
                            #if os(iOS)
                            .background(Color(.systemGray5))
                            #else
                            .background(Color(nsColor: .systemGray))
                            #endif
                            .foregroundStyle(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Barcode Linked")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
