//
//  ProductPickerView.swift
//  Grocy Mobile
//
//  Reusable product picker component
//

import SwiftUI
import SwiftData

struct ProductPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<MDProduct> { $0.active }, sort: \MDProduct.name) private var mdProducts: [MDProduct]
    
    let onSelectProduct: (MDProduct) -> Void
    
    @State private var searchText = ""
    
    private var filteredProducts: [MDProduct] {
        if searchText.isEmpty {
            return mdProducts
        } else {
            return mdProducts.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredProducts, id: \.id) { product in
                    Button {
                        onSelectProduct(product)
                        dismiss()
                    } label: {
                        HStack {
                            Text(product.name)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search products")
            .navigationTitle("Select Product")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview(traits: .previewData) {
    ProductPickerView { _ in }
}
