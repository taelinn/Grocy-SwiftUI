//
//  UserPicker.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 10.12.25.
//

import SwiftData
import SwiftUI

struct UserPicker: View {
    @Binding var selection: String?
    let users: GrocyUsers

    private var selectedUserIDs: Set<Int> {
        guard let selection else { return [] }
        let components = selection.split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces))! }
        return Set(components)
    }

    private func toggleUser(_ userID: Int) {
        var selected = selectedUserIDs
        if selected.contains(userID) {
            selected.remove(userID)
        } else {
            selected.insert(userID)
        }

        selection =
            selected
            .sorted()
            .map { String($0) }
            .joined(separator: ",")
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(users) { user in
                UserSelectButton(
                    user: user,
                    isSelected: selectedUserIDs.contains(user.id)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        toggleUser(user.id)
                    }
                }
            }
        }
    }
}

struct UserSelectButton: View {
    let user: GrocyUser
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Text(user.displayName)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular.tint(isSelected ? .accentColor : .secondary).interactive(), in: .capsule)
            .contentShape(.capsule)
            .onTapGesture(perform: action)
    }
}

#Preview(traits: .previewData) {
    @Previewable @State var selection: String? = "1,3"
    @Previewable @Query var users: GrocyUsers

    Form {
        Text(selection ?? "")
        UserPicker(selection: $selection, users: users)
    }
}
