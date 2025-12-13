//
//  MDTaskCategoyRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 12.12.25.
//
import SwiftUI

struct MDTaskCategoryRowView: View {
    var taskCategory: MDTaskCategory

    var body: some View {
        VStack(alignment: .leading) {
            Text(taskCategory.name)
                .font(.title)
                .foregroundStyle(taskCategory.active ? .primary : .secondary)
            if !taskCategory.mdTaskCategoryDescription.isEmpty {
                Text(taskCategory.mdTaskCategoryDescription)
                    .font(.caption)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

#Preview {
    List {
        MDTaskCategoryRowView(taskCategory: MDTaskCategory(name: "Task category"))
        MDTaskCategoryRowView(taskCategory: MDTaskCategory(name: "Task category with Desc", mdTaskCategoryDescription: "Description"))
        MDTaskCategoryRowView(taskCategory: MDTaskCategory(name: "Inactive", active: false))
    }
}
