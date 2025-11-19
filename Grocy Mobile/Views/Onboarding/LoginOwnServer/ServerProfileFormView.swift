//
//  ServerProfileFormView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 17.11.25.
//

import AVFoundation
import SwiftData
import SwiftUI

struct ListElementRow: View {
    @Bindable var header: LoginCustomHeader

    var body: some View {
        HStack {
            TextField("Name", text: $header.headerName)
                .autocorrectionDisabled(true)
            Text(":")
            TextField("Value", text: $header.headerValue)
                .autocorrectionDisabled(true)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
        }
    }
}

struct ServerProfileFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var serverProfile: ServerProfile
    var isEditing: Bool = false

    init(serverProfile: ServerProfile? = nil) {
        if serverProfile != nil {
            isEditing = true
        }
        self.serverProfile = serverProfile ?? ServerProfile()
    }

    var selectedServerProfile: ServerProfile? {
        let descriptor = FetchDescriptor<ServerProfile>(predicate: #Predicate<ServerProfile> { $0.isActive == true })
        return (try? modelContext.fetch(descriptor))?.first
    }

    #if os(iOS)
        @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
        @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?

        @State private var isShowingGrocyScanner: Bool = false
        func handleGrocyScan(result: Result<CodeScannerViewLegacy.ScanResult, CodeScannerViewLegacy.ScanError>) {
            self.isShowingGrocyScanner = false
            switch result {
            case .success(let code):
                let grocyServerData = code.string.components(separatedBy: "|")
                guard grocyServerData.count == 2 else { return }

                let serverURL = grocyServerData[0]
                let apiKey = grocyServerData[1]

                if apiKey.count == 50 {
                    serverProfile.grocyServerURL = serverURL
                    serverProfile.grocyAPIKey = apiKey
                }
            case .failure(let error):
                print("Scanning failed")
                print(error)
            }
        }

        @State private var isShowingTokenScanner: Bool = false
        func handleTokenScan(result: Result<CodeScannerViewLegacy.ScanResult, CodeScannerViewLegacy.ScanError>) {
            self.isShowingTokenScanner = false
            switch result {
            case .success(let scannedHassToken):
                serverProfile.hassToken = scannedHassToken.string
            case .failure(let error):
                print("Scanning failed")
                print(error)
            }
        }
    #endif

    var body: some View {
        Form {
            Section("Server") {
                MyTextField(
                    textToEdit: $serverProfile.name,
                    description: "Name",
                    isCorrect: Binding.constant(true),
                    leadingIcon: MySymbols.name
                )
                MyTextField(
                    textToEdit: $serverProfile.grocyServerURL,
                    description: "Server URL",
                    isCorrect: Binding.constant(true),
                    leadingIcon: "network",
                    helpText: "Server-URL of your Grocy Instance (if you use Home Assistant Ingress, this can be accessed via right click on REST API Browser in the web interface)"
                )
                .textContentType(.URL)
                #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled(true)

                MyTextField(
                    textToEdit: $serverProfile.grocyAPIKey,
                    description: "Valid API key",
                    isCorrect: Binding.constant(true),
                    leadingIcon: "key",
                    helpText: "API key for the user which is shown in the Manage API keys webview. If none exist, you need to create a new one."
                )
                .autocorrectionDisabled(true)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                if !serverProfile.grocyServerURL.isEmpty, let manageKeysURL = URL(string: "\(serverProfile.grocyServerURL)/manageapikeys") {
                    Link(
                        destination: manageKeysURL,
                        label: {
                            Label("Create API key", systemImage: "key")
                        }
                    )
                }
                #if os(iOS)
                    Button(
                        action: {
                            isShowingGrocyScanner.toggle()
                        },
                        label: {
                            Label("QR-Scan", systemImage: MySymbols.qrScan)
                        }
                    )
                    .sheet(
                        isPresented: $isShowingGrocyScanner,
                        content: {
                            CodeScannerViewLegacy(
                                codeTypes: [.qr],
                                scanMode: .once,
                                simulatedData: "http://192.168.178.40:8123/api/hassio_ingress/ckgy-GNrulcboPPwZyCnOn181YpRqOr6vIC8G2lijqU/api|tkYf677yotIwTibP0ko1lZxn8tj4cgoecWBMropiNc1MCjup8p",
                                completion: self.handleGrocyScan
                            )
                        }
                    )
                #endif
            }
            Section("Home Assistant Ingress") {
                MyToggle(isOn: $serverProfile.useHassIngress, description: "Use Home Assistant Ingress", icon: "house")
                if serverProfile.useHassIngress {
                    HStack {
                        MyTextField(
                            textToEdit: $serverProfile.hassToken,
                            description: "Long-Term-Token for Home Assistant",
                            isCorrect: Binding.constant(true),
                            leadingIcon: "key",
                            helpText:
                                "This token has to be generated out of your Home Assistant Web interface. To do this, open your Home Assistant Profile page, scroll down to Long-Lived Access Tokens and create one. Name it and copy the resulting Token in the App or create a QR Code and scan it (iOS)."
                        )
                        .autocorrectionDisabled(true)
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #endif
                        #if os(iOS)
                            Button(
                                action: {
                                    isShowingTokenScanner.toggle()
                                },
                                label: {
                                    Image(systemName: MySymbols.qrScan)
                                }
                            )
                            .sheet(
                                isPresented: $isShowingTokenScanner,
                                content: {
                                    CodeScannerViewLegacy(
                                        codeTypes: [.qr],
                                        scanMode: .once,
                                        simulatedData: "670f7d46391db7b42d382ebc9ea667f3aac94eb90219b9e32c7cd71cd37d13833109113270b327fac08d77d9b038a9cb3ab6cfd8dc8d0e3890d16e6434d10b3d",
                                        completion: self.handleTokenScan
                                    )
                                }
                            )
                        #endif
                    }
                }
                Link(
                    destination: URL(string: "https://github.com/supergeorg/Grocy-SwiftUI/blob/main/Guides/Home%20Assistant%20Ingress/HomeAssistantIngressGuide.md")!,
                    label: {
                        Label("Guide (English)", systemImage: "questionmark.circle")
                    }
                )
            }
            Section(
                content: {
                    ForEach(serverProfile.customHeaders) { customHeader in
                        ListElementRow(header: customHeader)
                    }
                    .onDelete(perform: deleteHeader)
                },
                header: {
                    HStack {
                        Text("Custom Headers")
                        Spacer()
                        Button(
                            action: {
                                serverProfile.customHeaders.append(LoginCustomHeader(headerName: "", headerValue: ""))
                            },
                            label: {
                                Label("Add", systemImage: MySymbols.new)
                            }
                        )
                    }
                }
            )
        }
        .navigationTitle("Own server")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button(
                        role: .cancel,
                        action: {
                            dismiss()
                        }
                    )
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(
                    role: .confirm,
                    action: {
                        if isEditing {
                            try? modelContext.save()
                        } else {
                            if selectedServerProfile == nil {
                                serverProfile.isActive = true
                            }
                            modelContext.insert(serverProfile)
                        }
                        dismiss()
                    }
                )
                .disabled(serverProfile.grocyServerURL.isEmpty || serverProfile.grocyAPIKey.isEmpty)
            }
        }
    }

    private func deleteHeader(at offsets: IndexSet) {
        serverProfile.customHeaders.remove(atOffsets: offsets)
    }
}
