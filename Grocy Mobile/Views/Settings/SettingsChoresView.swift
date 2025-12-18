//
//  SettingsChoreView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 18.12.25.
//

import SwiftUI

struct SettingsChoresView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @AppStorage("devMode") private var devMode: Bool = false

    @State private var isFirst: Bool = true

    private let dataToUpdate: [ObjectEntities] = [.locations, .product_groups, .quantity_units]

    var body: some View {
        Form {
            Section("Chores overview") {
                ServerSettingsIntStepper(
                    settingKey: GrocyUserSettings.CodingKeys.choresDueSoonDays.rawValue,
                    description: "Due soon days",
                    descriptionInfo: "Set to 0 to hide due soon filters/highlighting",
                    icon: MySymbols.date
                )
                ServerSettingsToggle(
                    settingKey: GrocyUserSettings.CodingKeys.choresOverviewSwapTrackingButtons.rawValue,
                    description: "Swap track next schedule / track now buttons",
                    icon: MySymbols.choreTrackNext
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Chores settings")
        .task {
            if isFirst {
                await grocyVM.requestData(objects: dataToUpdate)
                isFirst = false
            }
        }
        .onDisappear(perform: {
            Task {
                await grocyVM.requestData(additionalObjects: [.user_settings])
            }
        })
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        SettingsChoresView()
    }
}
