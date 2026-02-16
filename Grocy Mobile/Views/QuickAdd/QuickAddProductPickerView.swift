//
//  QuickAddProductPickerView.swift
//  Grocy Mobile
//
//  Product picker for adding favorites to Quick Add
//

import SwiftUI
import SwiftData

struct QuickAddProductPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.profileModelContext) private var modelContext
    @Environment(GrocyViewModel.self) private var grocyVM
    
    @Query(filter: #Predicate<MDProduct> { $0.active }, sort: \MDProduct.name) private var mdProducts: [MDProduct]
    
    private var currentServerURL: String {
        grocyVM.selectedServerProfile?.grocyServerURL ?? ""
    }
    
    private var favorites: [QuickAddFavorite] {
        let serverURL = currentServerURL
        let descriptor = FetchDescriptor<QuickAddFavorite>(
            predicate: #Predicate { $0.grocyServerURL == serverURL }
        )
        guard let context = modelContext else { return [] }
        return (try? context.fetch(descriptor)) ?? []
    }
    
    @State private var searchText = ""
    
    var onSelectProduct: (Int) -> Void
    
    private var favoriteProductIDs: Set<Int> {
        Set(favorites.map { $0.productID })
    }
    
    private var filteredProducts: [MDProduct] {
        if searchText.isEmpty {
            return mdProducts.filter { !favoriteProductIDs.contains($0.id) }
        } else {
            return mdProducts.filter {
                !favoriteProductIDs.contains($0.id) &&
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredProducts, id: \.id) { product in
                Button {
                    onSelectProduct(product.id)
                    dismiss()
                } label: {
                    HStack {
                        Text(product.name)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search products")
        .navigationTitle("Add to Quick Add")
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

#Preview(traits: .previewData) {
    NavigationStack {
        QuickAddProductPickerView { _ in }
    }
}
