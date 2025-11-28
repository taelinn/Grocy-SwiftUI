//
//  RefreshButton.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 05.11.21.
//

import SwiftUI

struct RefreshButton: View {
    let updateData: () async -> Void

    @State private var isLoading: Bool = false

    var body: some View {
        Button(
            action: {
                isLoading = true
                Task {
                    await updateData()
                    isLoading = false
                }
            },
            label: {
                Image(systemName: MySymbols.reload)
                    .symbolEffect(.rotate, isActive: isLoading)
            }
        )
    }
}

#Preview {
    Form {
        RefreshButton(updateData: {
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            }
        })
    }
}
