//
//  BarcodeBuddyViewModel.swift
//  Grocy Mobile
//
//  BarcodeBuddy state management
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
class BarcodeBuddyViewModel {
    var unknownBarcodes: [BBUnknownBarcode] = []
    var barcodeLogs: [BBBarcodeLog] = []
    var isLoading = false
    var errorMessage: String?
    var isConnected = false
    
    private var api: BarcodeBuddyAPI?
    private var modelContext: ModelContext?
    
    // MARK: - Computed Properties
    
    var newBarcodes: [BBUnknownBarcode] {
        unknownBarcodes.filter { $0.isLookedUp }
    }
    
    var trulyUnknownBarcodes: [BBUnknownBarcode] {
        unknownBarcodes.filter { !$0.isLookedUp }
    }
    
    var totalUnresolvedCount: Int {
        unknownBarcodes.count
    }
    
    // MARK: - Configuration
    
    func configure(serverURL: String, apiKey: String, modelContext: ModelContext? = nil) {
        self.api = BarcodeBuddyAPI(serverURL: serverURL, apiKey: apiKey)
        self.modelContext = modelContext
    }
    
    // MARK: - API Methods
    
    func fetchUnknownBarcodes() async {
        guard let api = api else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await api.getUnknownBarcodes()
            unknownBarcodes = data.barcodes
            isConnected = true
            
            // Update cache for widget with separate counts
            let newCount = newBarcodes.count
            let unknownCount = trulyUnknownBarcodes.count
            await updateWidgetCache(newCount: newCount, unknownCount: unknownCount)
        } catch {
            errorMessage = error.localizedDescription
            isConnected = false
            GrocyLogger.error("Failed to fetch unknown barcodes: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func updateWidgetCache(newCount: Int, unknownCount: Int) async {
        guard let modelContext = modelContext else { return }
        
        do {
            // Fetch or create cache
            let descriptor = FetchDescriptor<BarcodeBuddyCache>()
            let results = try modelContext.fetch(descriptor)
            
            if let cache = results.first {
                cache.newBarcodesCount = newCount
                cache.unknownBarcodesCount = unknownCount
                cache.totalCount = newCount + unknownCount
                cache.lastUpdated = Date()
            } else {
                let newCache = BarcodeBuddyCache(
                    newBarcodesCount: newCount,
                    unknownBarcodesCount: unknownCount,
                    lastUpdated: Date()
                )
                modelContext.insert(newCache)
            }
            
            try modelContext.save()
        } catch {
            GrocyLogger.error("Failed to update widget cache: \(error)")
        }
    }
    
    func fetchBarcodeLogs(limit: Int = 50) async {
        guard let api = api else { return }
        
        do {
            let data = try await api.getBarcodeLogs(limit: limit)
            barcodeLogs = data.logs
        } catch {
            GrocyLogger.error("Failed to fetch barcode logs: \(error.localizedDescription)")
        }
    }
    
    func deleteBarcode(id: Int) async -> Bool {
        guard let api = api else { return false }
        
        do {
            _ = try await api.deleteBarcode(id: id)
            // Remove from local array
            unknownBarcodes.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            GrocyLogger.error("Failed to delete barcode: \(error.localizedDescription)")
            return false
        }
    }
    
    func associateBarcode(id: Int, productId: Int) async -> Bool {
        guard let api = api else { return false }
        
        do {
            _ = try await api.associateBarcode(id: id, productId: productId)
            // Remove from local array
            unknownBarcodes.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            GrocyLogger.error("Failed to associate barcode: \(error.localizedDescription)")
            return false
        }
    }
    
    func testConnection() async -> Bool {
        guard let api = api else { return false }
        
        do {
            isConnected = try await api.testConnection()
            return isConnected
        } catch {
            errorMessage = error.localizedDescription
            isConnected = false
            return false
        }
    }
    
    func refresh() async {
        await fetchUnknownBarcodes()
        await fetchBarcodeLogs()
    }
}
