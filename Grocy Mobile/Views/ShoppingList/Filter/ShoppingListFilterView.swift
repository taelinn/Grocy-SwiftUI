//
//  ShoppingListFilterView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 28.08.25.
//

import SwiftData
import SwiftUI

struct ShoppingListFilterView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.colorScheme) var colorScheme

    @Binding var filteredStatus: ShoppingListStatus

    private var rowBackground: Color? {
        switch filteredStatus {
        case .all: return nil
        case .done: return Color(.GrocyColors.grocyGreen).opacity(0.3)
        case .undone: return Color(.GrocyColors.grocyGrayBackground)
        case .belowMinStock: return Color(.GrocyColors.grocyBlueBackground)
        }
    }

    var body: some View {
        List {
            Picker(
                selection: $filteredStatus,
                content: {
                    Text("All")
                        .tag(ShoppingListStatus.all)
                    Text("Below min. stock amount")
                        .tag(ShoppingListStatus.belowMinStock)
                    Text("Only done items")
                        .tag(ShoppingListStatus.done)
                    Text("Only undone items")
                        .tag(ShoppingListStatus.undone)
                },
                label: {
                    Label("Status", systemImage: MySymbols.filter)
                }
            )
            #if os(iOS)
                .id(filteredStatus)
                .foregroundStyle(.primary)
                .listRowBackground(rowBackground)
            #endif
        }
    }
}

#Preview(traits: .previewData) {
    @Previewable @State var filteredStatus: ShoppingListStatus = .all

    ShoppingListFilterView(filteredStatus: $filteredStatus)
}
