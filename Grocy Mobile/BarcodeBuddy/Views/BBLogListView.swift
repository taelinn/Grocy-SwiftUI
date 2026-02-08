//
//  BBLogListView.swift
//  Grocy Mobile
//
//  Barcode processing history view
//

import SwiftUI

struct BBLogListView: View {
    @Bindable var viewModel: BarcodeBuddyViewModel
    
    var body: some View {
        Group {
            if viewModel.barcodeLogs.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock")
                } description: {
                    Text("Barcode processing history will appear here")
                }
            } else {
                List {
                    ForEach(viewModel.barcodeLogs) { log in
                        Text(log.log)
                            .font(.body)
                    }
                }
            }
        }
        .refreshable {
            await viewModel.fetchBarcodeLogs()
        }
    }
}
