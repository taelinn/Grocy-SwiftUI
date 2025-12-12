//
//  ChoreLogFilterView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 11.12.25.
//

import SwiftData
import SwiftUI

struct ChoreLogFilterView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query(sort: \Chore.choreName, order: .forward) var chores: Chores
    @Query(sort: \GrocyUser.id, order: .forward) var grocyUsers: GrocyUsers

    @Binding var filteredChoreID: Int?
    @Binding var filteredUserID: Int?

    var body: some View {
        List {
            Picker(
                selection: $filteredChoreID,
                content: {
                    Text("All").tag(nil as Int?)
                    ForEach(chores, id: \.id) { chore in
                        Text(chore.choreName).tag(chore.id as Int?)
                    }
                },
                label: {
                    Label("Chore", systemImage: MySymbols.filter)
                        .foregroundStyle(.primary)
                }
            )
            Picker(
                selection: $filteredUserID,
                content: {
                    Text("All").tag(nil as Int?)
                    ForEach(grocyUsers, id: \.id) { user in
                        Text(user.displayName).tag(user.id as Int?)
                    }
                },
                label: {
                    Label("User", systemImage: MySymbols.filter)
                        .foregroundStyle(.primary)
                }
            )
        }
    }
}

#Preview(traits: .previewData) {
    @Previewable @State var filteredChoreID: Int? = nil
    @Previewable @State var filteredUserID: Int? = nil

    NavigationStack {
        ChoreLogFilterView(filteredChoreID: $filteredChoreID, filteredUserID: $filteredUserID)
    }
}
