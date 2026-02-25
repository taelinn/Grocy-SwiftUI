//
//  QuickScanManualSearchView.swift
//  Grocy Mobile
//
//  Created with Claude Code
//

import SwiftData
import SwiftUI

struct QuickScanManualSearchView: View {
    @Environment(\.dismiss) var dismiss
    
    @Query(sort: \MDProduct.name, order: .forward) var mdProducts: MDProducts
    
    @Binding var selectedProductID: Int?
    
    @State private var searchTerm: String = ""
    
    private var filteredProducts: MDProducts {
        mdProducts.filter {
            searchTerm.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchTerm)
        }
        .filter {
            $0.noOwnStock != true
        }
        .filter {
            $0.active
        }
        .sorted(by: {
            $0.name.lowercased() < $1.name.lowercased()
        })
    }
    
    var body: some View {
        List {
            ForEach(filteredProducts, id: \.id) { product in
                Button(action: {
                    selectedProductID = product.id
                }) {
                    HStack {
                        Text(product.name)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Search products")
        .searchable(text: $searchTerm, prompt: "Search by name")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            }
        }
        .onChange(of: selectedProductID) {
            if selectedProductID != nil {
                dismiss()
            }
        }
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        QuickScanManualSearchView(selectedProductID: .constant(nil))
    }
}
