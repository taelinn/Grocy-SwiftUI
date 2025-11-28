//
//  ErrorMessageView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 13.10.23.
//

import SwiftUI

struct ErrorMessageView: View {
    var errorMessage: String

    var body: some View {
        Section {
            Label(errorMessage, systemImage: MySymbols.error)
                .foregroundStyle(.primary)
                .listRowBackground(Color.red)
        }
    }
}

#Preview {
    Form {
        ErrorMessageView(errorMessage: "Error Message")
    }
}
