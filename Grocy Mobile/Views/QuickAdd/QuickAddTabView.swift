//
//  QuickAddTabView.swift
//  Grocy Mobile
//
//  Quick access tab for adding favorite products to stock
//

import SwiftUI
import SwiftData

struct QuickAddTabView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<MDProduct> { $0.active }, sort: \MDProduct.name) private var mdProducts: [MDProduct]
    @Query(sort: \MDProductGroup.name) private var productGroups: [MDProductGroup]
    @Query(filter: #Predicate<MDLocation> { $0.active }, sort: \MDLocation.name) private var mdLocations: [MDLocation]
    
    private var currentServerURL: String {
        grocyVM.selectedServerProfile?.grocyServerURL ?? ""
    }
    
    private var favorites: [QuickAddFavorite] {
        let serverURL = currentServerURL
        let descriptor = FetchDescriptor<QuickAddFavorite>(
            predicate: #Predicate { $0.grocyServerURL == serverURL },
            sortBy: [SortDescriptor(\QuickAddFavorite.sortOrder)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private var favoriteProducts: [MDProduct] {
        let favoriteProductIDs = Set(favorites.map { $0.productID })
        let products = mdProducts.filter { favoriteProductIDs.contains($0.id) }
        
        if searchText.isEmpty {
            return products
        } else {
            return products.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    @State private var isEditing = false
    @State private var showingProductPicker = false
    @State private var selectedFavorite: QuickAddFavorite?
    @State private var isRefreshing = false
    @State private var searchText = ""
    
    private func product(for favorite: QuickAddFavorite) -> MDProduct? {
        mdProducts.first(where: { $0.id == favorite.productID })
    }
    
    private func productGroup(for product: MDProduct) -> MDProductGroup? {
        guard let groupID = product.productGroupID else { return nil }
        return productGroups.first(where: { $0.id == groupID })
    }
    
    private func favorites(for productGroup: MDProductGroup) -> [QuickAddFavorite] {
        let productsInGroup = favoriteProducts.filter { $0.productGroupID == productGroup.id }
        let productIDsInGroup = Set(productsInGroup.map { $0.id })
        return favorites.filter { productIDsInGroup.contains($0.productID) }
    }
    
    private var uncategorizedFavorites: [QuickAddFavorite] {
        let uncategorizedProducts = favoriteProducts.filter { $0.productGroupID == nil }
        let uncategorizedProductIDs = Set(uncategorizedProducts.map { $0.id })
        return favorites.filter { uncategorizedProductIDs.contains($0.productID) }
    }
    
    // Get product groups that have at least one favorite
    private var groupsWithFavorites: [MDProductGroup] {
        productGroups.filter { group in
            !favorites(for: group).isEmpty
        }
    }
    
    var body: some View {
        Group {
            if favorites.isEmpty {
                emptyStateView
            } else {
                favoritesList
            }
        }
        .navigationTitle("Quick Add")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search favorites")
        .toolbar {
            if !favorites.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingProductPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isEditing)
            }
        }
        .sheet(isPresented: $showingProductPicker) {
            NavigationStack {
                QuickAddProductPickerView { productID in
                    Task {
                        await addFavorite(productID: productID)
                    }
                }
            }
        }
        .sheet(item: $selectedFavorite) { favorite in
            if let product = product(for: favorite) {
                NavigationStack {
                    QuickAddPurchaseSheet(product: product, favorite: favorite)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Favorites", systemImage: "star")
        } description: {
            VStack(spacing: 12) {
                Text("Quick Add lets you add frequently purchased products to stock with a single tap.")
                    .multilineTextAlignment(.center)
                
                Text("To get started:")
                    .font(.headline)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                            .fontWeight(.semibold)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create UserFields in Grocy")
                                .fontWeight(.semibold)
                            Group {
                                Text("Required: quick_add (Checkbox, Products)")
                                Text("Optional: note_required (Checkbox, Products)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text("Tip: Both fields also work on Product Groups!")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                            .fontWeight(.semibold)
                        Text("Mark products/groups as favorites in Grocy")
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                            .fontWeight(.semibold)
                        Text("Go to Settings → Sync Quick Add favorites")
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("4.")
                            .fontWeight(.semibold)
                        Text("Or tap + above to add products manually")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
        } actions: {
            Button {
                showingProductPicker = true
            } label: {
                Text("Add Product")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var favoritesList: some View {
        List {
            ForEach(groupsWithFavorites) { group in
                Section {
                    ForEach(favorites(for: group)) { favorite in
                        favoriteRow(favorite)
                    }
                    .onDelete { offsets in
                        deleteFavorites(in: group, at: offsets)
                    }
                    .onMove { source, destination in
                        moveFavorites(in: group, from: source, to: destination)
                    }
                } header: {
                    Text(group.name)
                }
            }
            
            if !uncategorizedFavorites.isEmpty {
                Section {
                    ForEach(uncategorizedFavorites) { favorite in
                        favoriteRow(favorite)
                    }
                    .onDelete { offsets in
                        deleteUncategorizedFavorites(at: offsets)
                    }
                    .onMove { source, destination in
                        moveUncategorizedFavorites(from: source, to: destination)
                    }
                } header: {
                    Text("Uncategorized")
                }
            }
        }
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .refreshable {
            await syncFromServer()
        }
    }
    
    private func favoriteRow(_ favorite: QuickAddFavorite) -> some View {
        Group {
            if let product = product(for: favorite) {
                Button {
                    if !isEditing {
                        selectedFavorite = favorite
                    }
                } label: {
                    HStack {
                        if isEditing {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            if let location = mdLocations.first(where: { $0.id == product.locationID }) {
                                Text(location.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !isEditing {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.title2)
                        }
                    }
                }
                .disabled(isEditing)
            }
        }
    }
    
    private func addFavorite(productID: Int) async {
        let serverURL = currentServerURL
        guard !serverURL.isEmpty else {
            GrocyLogger.error("Cannot add favorite: no active server profile")
            return
        }
        
        // Set favorite on server
        do {
            try await grocyVM.setProductFavorite(productID: productID, isFavorite: true)
            
            // Create local favorite
            let newFavorite = QuickAddFavorite(
                productID: productID,
                sortOrder: favorites.count,
                grocyServerURL: serverURL
            )
            modelContext.insert(newFavorite)
            try? modelContext.save()
            GrocyLogger.info("Added product \(productID) to Quick Add favorites")
        } catch {
            GrocyLogger.error("Failed to add favorite: \(error)")
        }
    }
    
    private func deleteFavorites(in group: MDProductGroup, at offsets: IndexSet) {
        let groupFavorites = favorites(for: group)
        Task {
            for index in offsets {
                let favorite = groupFavorites[index]
                
                // Clear favorite on server
                do {
                    try await grocyVM.setProductFavorite(productID: favorite.productID, isFavorite: false)
                } catch {
                    GrocyLogger.error("Failed to clear favorite on server: \(error)")
                }
                
                // Delete locally
                modelContext.delete(favorite)
            }
            try? modelContext.save()
            reorderFavorites(in: group)
        }
    }
    
    private func deleteUncategorizedFavorites(at offsets: IndexSet) {
        let uncategorized = uncategorizedFavorites
        Task {
            for index in offsets {
                let favorite = uncategorized[index]
                
                // Clear favorite on server
                do {
                    try await grocyVM.setProductFavorite(productID: favorite.productID, isFavorite: false)
                } catch {
                    GrocyLogger.error("Failed to clear favorite on server: \(error)")
                }
                
                // Delete locally
                modelContext.delete(favorite)
            }
            try? modelContext.save()
            reorderUncategorizedFavorites()
        }
    }
    
    private func moveFavorites(in group: MDProductGroup, from source: IndexSet, to destination: Int) {
        var reorderedFavorites = favorites(for: group)
        reorderedFavorites.move(fromOffsets: source, toOffset: destination)
        
        for (index, favorite) in reorderedFavorites.enumerated() {
            favorite.sortOrder = index
        }
        try? modelContext.save()
    }
    
    private func moveUncategorizedFavorites(from source: IndexSet, to destination: Int) {
        var reorderedFavorites = uncategorizedFavorites
        reorderedFavorites.move(fromOffsets: source, toOffset: destination)
        
        for (index, favorite) in reorderedFavorites.enumerated() {
            favorite.sortOrder = index
        }
        try? modelContext.save()
    }
    
    private func reorderFavorites(in group: MDProductGroup) {
        let groupFavorites = favorites(for: group)
        for (index, favorite) in groupFavorites.enumerated() {
            favorite.sortOrder = index
        }
        try? modelContext.save()
    }
    
    private func reorderUncategorizedFavorites() {
        let uncategorized = uncategorizedFavorites
        for (index, favorite) in uncategorized.enumerated() {
            favorite.sortOrder = index
        }
        try? modelContext.save()
    }
    
    private func syncFromServer() async {
        do {
            try await grocyVM.syncFavoritesFromServer(modelContext: modelContext)
        } catch {
            GrocyLogger.error("Failed to sync favorites: \(error)")
        }
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        QuickAddTabView()
    }
}
