//
//  MDChoreRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 10.12.25.
//

import SwiftUI

struct MDChoreRowView: View {
    var chore: MDChore

    var body: some View {
        VStack(alignment: .leading) {
            Text(chore.name)
                .font(.title)
            if !chore.mdChoreDescription.isEmpty {
                Text(chore.mdChoreDescription)
                    .font(.caption)
            }
            Text("\(Text("Period type")): \(Text(chore.periodType.localizedName))")
        }
    }
}
