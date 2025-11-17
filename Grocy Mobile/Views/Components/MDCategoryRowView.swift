//
//  MDCategoryRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 17.11.25.
//

import SwiftData
import SwiftUI

struct MDCategoryRowView<T: PersistentModel>: View {
    @Environment(\.modelContext) private var modelContext

    let categoryName: LocalizedStringKey
    let iconName: String
    let mdType: T.Type

    private var itemCount: Int {
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 0
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    var body: some View {
        HStack {
            Label(categoryName, systemImage: iconName)
            if itemCount > 0 {
                Spacer()
                Text("\(itemCount)")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }
}
