//
//  MyTextField.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 28.10.20.
//

import SwiftUI

struct MyTextField: View {
    @Environment(\.isEnabled) var isEnabled: Bool
    @Binding var textToEdit: String
    var description: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var prompt: String = ""
    @Binding var isCorrect: Bool
    @FocusState private var isFocused: Bool
    var leadingIcon: String?
    var emptyMessage: LocalizedStringKey?
    var errorMessage: LocalizedStringKey?
    var helpText: LocalizedStringKey?

    var body: some View {
        LabeledContent {
            VStack(alignment: .leading, spacing: 0) {
                TextField(prompt, text: $textToEdit)
                    .foregroundColor(isEnabled ? .primary : .gray)
                    .padding(.vertical, 8)
                    .background(
                        VStack {
                            Spacer()
                            Color(!isCorrect && !textToEdit.isEmpty && errorMessage != nil ? .systemRed : .systemGray)
                                .frame(height: 2)
                        }
                    )

                if !isCorrect && !textToEdit.isEmpty, let errorMessage = errorMessage {
                    Text(errorMessage)
                        .lineLimit(nil)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }
                if textToEdit.isEmpty, let emptyMessage = emptyMessage {
                    Text(emptyMessage)
                        .lineLimit(nil)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }
            }
        } label: {
            if let leadingIcon = leadingIcon {
                Label(description, systemImage: leadingIcon)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(description)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let subtitle = subtitle {
                Text(subtitle)
                    .lineLimit(nil)
            }
            if let helpText = helpText {
                FieldDescription(description: helpText)
            }
        }
    }
}

#Preview {
    @Previewable @State var textToEdit: String = "Text to Edit"
    @Previewable @State var isCorrect: Bool = true
    
    Form {
        MyTextField(
            textToEdit: $textToEdit,
            description: "Description",
            subtitle: "Optional subtitle",
            isCorrect: $isCorrect,
            leadingIcon: "tag",
            errorMessage: "Error message",
            helpText: "This is a help text"
        )
        .onChange(of: textToEdit, {
            if textToEdit == "Error" { isCorrect = false } else { isCorrect = true }
        })
    }
}
