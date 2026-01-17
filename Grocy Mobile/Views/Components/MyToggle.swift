//
//  MyToggle.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 19.11.20.
//

import SwiftUI

struct MyToggle: View {
    @Binding var isOn: Bool
    var description: LocalizedStringKey
    var descriptionInfo: LocalizedStringKey?
    var icon: String?

    @State private var showInfo: Bool = false

    var body: some View {
        HStack(alignment: .center) {
            if let icon = icon {
                Label {
                    HStack {
                        Text(description)
                            .layoutPriority(1)
                        if let descriptionInfo = descriptionInfo {
                            FieldDescription(description: descriptionInfo)
                                .fixedSize()
                        }
                    }
                } icon: {
                    Image(systemName: icon).foregroundStyle(.primary)
                }
            } else {
                HStack {
                    Text(description)
                        .layoutPriority(1)
                    if let descriptionInfo = descriptionInfo {
                        FieldDescription(description: descriptionInfo)
                            .fixedSize()
                    }
                }
            }
            
            Spacer()
            
            // Toggle stays on the right
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .fixedSize()
        }
    }
}

#Preview {
    @Previewable @State var isOn: Bool = true

    Form {
        MyToggle(isOn: $isOn, description: "Description", descriptionInfo: "Descriptioninfo", icon: "tag")
        MyToggle(isOn: $isOn, description: "Enable tare weight handling", descriptionInfo: "Descriptioninfo", icon: "tag")
    }
}
