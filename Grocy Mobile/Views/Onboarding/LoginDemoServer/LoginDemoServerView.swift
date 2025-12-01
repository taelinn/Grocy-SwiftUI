//
//  LoginDemoServerView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 17.11.25.
//

import SwiftUI

struct LoginDemoServerView: View {
    @AppStorage("demoServerURL") var demoServerURL: String = GrocyAPP.DemoServers.noLanguage.rawValue

    var body: some View {
        Form {
            Picker(
                selection: $demoServerURL,
                label: Text("Demo server"),
                content: {
                    ForEach(
                        GrocyAPP.DemoServers.allCases,
                        content: { demoServer in
                            Text(demoServer.description).tag(demoServer.rawValue)
                        }
                    )
                }
            )
            .pickerStyle(.inline)
        }
        .navigationTitle("Demo server")
        .formStyle(.grouped)
        .safeAreaBar(
            edge: .bottom,
            content: {
                NavigationLink(
                    value: LoginDestination(type: .demoServer),
                    label: {
                        Label("Login", systemImage: MySymbols.login)
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                            .padding()
                    }
                )
                .glassEffect(.regular.tint(.green).interactive())
                .contentShape(Capsule())
            }
        )
    }
}

#Preview {
    @Previewable @AppStorage("demoServerURL") var demoServerURL: String = GrocyAPP.DemoServers.noLanguage.rawValue
    
    NavigationStack {
        LoginDemoServerView(demoServerURL: demoServerURL)
    }
}
