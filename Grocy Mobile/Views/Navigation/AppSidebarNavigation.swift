//
//  AppSidebarNavigation.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 12.11.20.
//

import SwiftUI

struct AppSidebarNavigation: View {
    @Environment(DeepLinkManager.self) var deepLinkManager

    @State private var selection: NavigationItem? = .none

    var body: some View {
        NavigationSplitView(
            sidebar: {
                Sidebar(selection: $selection)
            },
            detail: {
                NavigationStack {
                    Navigation(selection: $selection)
                }
            }
        )
        .onAppear {
            if deepLinkManager.pendingStockFilter != nil {
                selection = .stockOverview
            }
        }
        .onChange(of: deepLinkManager.pendingStockFilter) { _, newValue in
            if newValue != nil {
                selection = .stockOverview
            }
        }
    }
}

#Preview {
    AppSidebarNavigation()
}
