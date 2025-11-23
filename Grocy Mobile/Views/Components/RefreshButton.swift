//
//  RefreshButton.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 05.11.21.
//

import SwiftUI

struct RefreshButton: View {
    let updateData: () -> Void

    @State private var isLoading: Bool = false

    var body: some View {
        Button(
            action: {
                isLoading = true
                updateData()
                isLoading = false
            },
            label: {
                Image(systemName: MySymbols.reload)
                    .symbolEffect(.rotate, isActive: isLoading)
            }
        )
    }
}

#Preview {
    RefreshButton(updateData: { print("Update") })
}
