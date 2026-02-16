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
    @Environment(\.profileModelContext) private var modelContext
    
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
        guard let context = modelContext else {
            GrocyLogger.error("QuickAdd: No profile model context available")
            return []
        }
        
        let results = (try? context.fetch(descriptor)) ?? []
        
        GrocyLogger.info("QuickAdd: Fetched \(results.count) favorites for server: \(serverURL)")
        if results.isEmpty {
            GrocyLogger.warning("QuickAdd: No favorites found - checking all favorites in DB")
            let allDescriptor = FetchDescriptor<QuickAddFavorite>()
            if let allFavorites = try? context.fetch(allDescriptor) {
                GrocyLogger.info("QuickAdd: Total favorites in DB: \(allFavorites.count)")
                for fav in allFavorites.prefix(5) {
                    GrocyLogger.info("QuickAdd:   - ID: \(fav.id), ProductID: \(fav.productID), ServerURL: \(fav.grocyServerURL)")
                }
            }
        }
        
        return results
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
        .refreshable {
            await syncFromServer()
        }
        .task {
            await migrateExistingFavorites()
        }
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
                Task {
                    await syncFromServer()
                }
            } label: {
                if isRefreshing {
                    ProgressView()
                } else {
                    Text("Sync Favorites")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRefreshing)
            
            Button {
                showingProductPicker = true
            } label: {
                Text("Add Product")
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
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
            GrocyLogger.error("QuickAdd: Cannot add favorite: no active server profile")
            return
        }
        
        GrocyLogger.info("QuickAdd: Adding favorite - ProductID: \(productID), ServerURL: \(serverURL)")
        
        guard let context = modelContext else {
            GrocyLogger.error("QuickAdd: Cannot add favorite - no profile model context")
            return
        }
        
        // Check if favorite already exists (manual uniqueness check since CloudKit doesn't support unique constraints)
        let expectedID = "\(serverURL)_\(productID)"
        let checkDescriptor = FetchDescriptor<QuickAddFavorite>(
            predicate: #Predicate { $0.id == expectedID }
        )
        if let existingFavorites = try? context.fetch(checkDescriptor), !existingFavorites.isEmpty {
            GrocyLogger.info("QuickAdd: Favorite already exists - ID: \(expectedID)")
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
            context.insert(newFavorite)
            try context.save()
            GrocyLogger.info("QuickAdd: Successfully added favorite - ID: \(newFavorite.id), ProductID: \(productID), SortOrder: \(newFavorite.sortOrder)")
        } catch {
            GrocyLogger.error("QuickAdd: Failed to add favorite: \(error)")
        }
    }
    
    private func deleteFavorites(in group: MDProductGroup, at offsets: IndexSet) {
        let groupFavorites = favorites(for: group)
        Task {
            guard let context = modelContext else {
                GrocyLogger.error("QuickAdd: Cannot delete - no profile model context")
                return
            }
            
            for index in offsets {
                let favorite = groupFavorites[index]
                
                GrocyLogger.info("QuickAdd: Deleting favorite - ID: \(favorite.id), ProductID: \(favorite.productID), Group: \(group.name)")
                
                // Clear favorite on server
                do {
                    try await grocyVM.setProductFavorite(productID: favorite.productID, isFavorite: false)
                } catch {
                    GrocyLogger.error("QuickAdd: Failed to clear favorite on server: \(error)")
                }
                
                // Delete locally
                context.delete(favorite)
            }
            try context.save()
            GrocyLogger.info("QuickAdd: Deleted \(offsets.count) favorite(s) from group \(group.name)")
            reorderFavorites(in: group)
        }
    }
    
    private func deleteUncategorizedFavorites(at offsets: IndexSet) {
        let uncategorized = uncategorizedFavorites
        Task {
            guard let context = modelContext else {
                GrocyLogger.error("QuickAdd: Cannot delete - no profile model context")
                return
            }
            
            for index in offsets {
                let favorite = uncategorized[index]
                
                GrocyLogger.info("QuickAdd: Deleting uncategorized favorite - ID: \(favorite.id), ProductID: \(favorite.productID)")
                
                // Clear favorite on server
                do {
                    try await grocyVM.setProductFavorite(productID: favorite.productID, isFavorite: false)
                } catch {
                    GrocyLogger.error("QuickAdd: Failed to clear favorite on server: \(error)")
                }
                
                // Delete locally
                context.delete(favorite)
            }
            try context.save()
            GrocyLogger.info("QuickAdd: Deleted \(offsets.count) uncategorized favorite(s)")
            reorderUncategorizedFavorites()
        }
    }
    
    private func moveFavorites(in group: MDProductGroup, from source: IndexSet, to destination: Int) {
        guard let context = modelContext else { return }
        var reorderedFavorites = favorites(for: group)
        reorderedFavorites.move(fromOffsets: source, toOffset: destination)
        
        for (index, favorite) in reorderedFavorites.enumerated() {
            favorite.sortOrder = index
        }
        try? context.save()
    }
    
    private func moveUncategorizedFavorites(from source: IndexSet, to destination: Int) {
        guard let context = modelContext else { return }
        var reorderedFavorites = uncategorizedFavorites
        reorderedFavorites.move(fromOffsets: source, toOffset: destination)
        
        for (index, favorite) in reorderedFavorites.enumerated() {
            favorite.sortOrder = index
        }
        try? context.save()
    }
    
    private func reorderFavorites(in group: MDProductGroup) {
        guard let context = modelContext else { return }
        let groupFavorites = favorites(for: group)
        for (index, favorite) in groupFavorites.enumerated() {
            favorite.sortOrder = index
        }
        try? context.save()
    }
    
    private func reorderUncategorizedFavorites() {
        guard let context = modelContext else { return }
        let uncategorized = uncategorizedFavorites
        for (index, favorite) in uncategorized.enumerated() {
            favorite.sortOrder = index
        }
        try? context.save()
    }
    
    private func syncFromServer() async {
        isRefreshing = true
        let serverURL = currentServerURL
        GrocyLogger.info("QuickAdd: Starting sync from server - ServerURL: \(serverURL)")
        
        guard let context = modelContext else {
            GrocyLogger.error("QuickAdd: Cannot sync - no profile model context")
            isRefreshing = false
            return
        }
        
        do {
            try await grocyVM.syncFavoritesFromServer(modelContext: context)
            GrocyLogger.info("QuickAdd: Sync completed successfully")
        } catch {
            GrocyLogger.error("QuickAdd: Failed to sync favorites: \(error)")
        }
        isRefreshing = false
    }
    
    // One-time migration to fix existing QuickAddFavorite records
    private func migrateExistingFavorites() async {
        let migrationKey = "didMigrateQuickAddFavorites_v2"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            GrocyLogger.info("QuickAdd: Migration already completed, skipping")
            return // Already migrated
        }
        
        let serverURL = currentServerURL
        guard !serverURL.isEmpty else { 
            GrocyLogger.warning("QuickAdd: Cannot migrate - no server URL")
            return 
        }
        
        guard let context = modelContext else {
            GrocyLogger.error("QuickAdd: Cannot migrate - no profile model context")
            return
        }
        
        GrocyLogger.info("QuickAdd: Starting migration for server: \(serverURL)")
        
        // Fetch all favorites for current server
        let descriptor = FetchDescriptor<QuickAddFavorite>(
            predicate: #Predicate { $0.grocyServerURL == serverURL }
        )
        
        do {
            let allFavorites = try context.fetch(descriptor)
            var needsSave = false
            var migratedCount = 0
            
            GrocyLogger.info("QuickAdd: Found \(allFavorites.count) favorites to check for migration")
            
            for favorite in allFavorites {
                let expectedID = "\(favorite.grocyServerURL)_\(favorite.productID)"
                if favorite.id != expectedID {
                    GrocyLogger.info("QuickAdd: Migrating favorite - Old ID: '\(favorite.id)', New ID: '\(expectedID)'")
                    favorite.id = expectedID
                    needsSave = true
                    migratedCount += 1
                }
            }
            
            if needsSave {
                try context.save()
                GrocyLogger.info("QuickAdd: Successfully migrated \(migratedCount) of \(allFavorites.count) QuickAddFavorite records")
            } else {
                GrocyLogger.info("QuickAdd: No favorites needed migration")
            }
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKey)
            GrocyLogger.info("QuickAdd: Migration completed and marked as done")
        } catch {
            GrocyLogger.error("QuickAdd: Failed to migrate QuickAddFavorite records: \(error)")
        }
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        QuickAddTabView()
    }
}
