//
//  ContentView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 13.11.20.
//

import SwiftUI

struct ContentView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    
    @AppStorage("iPhoneTabNavigation") var iPhoneTabNavigation: Bool = true
    @AppStorage("iPadTabNavigation") var iPadTabNavigation: Bool = false

    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    @State private var isInitialLoadComplete = false

    var body: some View {
        Group {
            #if os(iOS)
                if (horizontalSizeClass == .compact && iPhoneTabNavigation) || iPadTabNavigation {
                    AppTabNavigation()
                } else {
                    AppSidebarNavigation()
                }
            #elseif os(macOS)
                AppSidebarNavigation()
                    .frame(minWidth: 500)
            #endif
        }
        .task {
            // Preload core data on app launch for instant UX
            guard !isInitialLoadComplete else { return }
            
            await grocyVM.requestData(
                objects: [
                    .products,              // Product master data
                    .product_barcodes,      // Barcode lookups
                    .locations,             // Storage locations
                    .quantity_units,        // Units (kg, pieces, etc.)
                    .quantity_unit_conversions, // Unit conversions
                    .product_groups,        // Product categories
                    .shopping_locations,    // Stores
                    .stock,                 // Stock entries (amounts per location)
                    .stock_current_locations // Current stock locations
                ],
                additionalObjects: [
                    .system_config,         // System configuration
                    .user_settings,         // User preferences
                    .stock                  // Computed stock view
                ]
            )
            
            isInitialLoadComplete = true
            GrocyLogger.info("Initial data preload complete")
        }
    }
}

#Preview {
    ContentView()
}
