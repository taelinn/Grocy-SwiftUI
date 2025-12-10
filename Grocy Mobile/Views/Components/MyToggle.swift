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
        Toggle(isOn: $isOn, label: {
            HStack {
                if let icon = icon {
                    Label(description, systemImage: icon)
                        .foregroundStyle(.primary)
                } else {
                    Text(description)
                }
                if let descriptionInfo = descriptionInfo {
                    FieldDescription(description: descriptionInfo)
                }
            }
        })
    }
}

#Preview {
    @Previewable @State var isOn: Bool = true
    
    Form {
        MyToggle(isOn: $isOn, description: "Description", descriptionInfo: "Descriptioninfo", icon: "tag")
    }
}
