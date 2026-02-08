//
//  BBSettingsView.swift
//  Grocy Mobile
//
//  BarcodeBuddy connection settings view
//

import SwiftUI
import SwiftData

struct BBSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var serverProfile: ServerProfile
    @State private var barcodeBuddyURL: String
    @State private var barcodeBuddyAPIKey: String
    @State private var isTestingConnection = false
    @State private var testResult: TestResult?
    
    enum TestResult {
        case success(String)
        case failure(String)
    }
    
    init(serverProfile: ServerProfile) {
        self.serverProfile = serverProfile
        _barcodeBuddyURL = State(initialValue: serverProfile.barcodeBuddyURL ?? "")
        _barcodeBuddyAPIKey = State(initialValue: serverProfile.barcodeBuddyAPIKey ?? "")
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Server URL", text: $barcodeBuddyURL)
                    .textContentType(.URL)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    #endif
                    .autocorrectionDisabled()
                
                TextField("API Key", text: $barcodeBuddyAPIKey)
                    .textContentType(.password)
                    #if os(iOS)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.none)
                    #endif
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("BarcodeBuddy Server")
            } footer: {
                Text("Enter your BarcodeBuddy server URL (e.g., http://192.168.1.50:9280) and API key.")
            }
            
            Section {
                Button {
                    Task {
                        await testConnection()
                    }
                } label: {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "network")
                        }
                        Text("Test Connection")
                    }
                }
                .disabled(barcodeBuddyURL.isEmpty || barcodeBuddyAPIKey.isEmpty || isTestingConnection)
                
                if let result = testResult {
                    switch result {
                    case .success(let message):
                        Label(message, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            
            if serverProfile.hasBBConfigured {
                Section {
                    Button(role: .destructive) {
                        clearConfiguration()
                    } label: {
                        Label("Disconnect BarcodeBuddy", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("BarcodeBuddy Setup")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveConfiguration()
                }
                .disabled(barcodeBuddyURL.isEmpty || barcodeBuddyAPIKey.isEmpty)
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func testConnection() async {
        isTestingConnection = true
        testResult = nil
        
        // Trim whitespace before testing (same as when saving)
        let trimmedURL = barcodeBuddyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = barcodeBuddyAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let api = BarcodeBuddyAPI(serverURL: trimmedURL, apiKey: trimmedAPIKey)
        
        do {
            let systemInfo = try await api.getSystemInfo()
            testResult = .success("Connected! Version: \(systemInfo.version)")
        } catch {
            testResult = .failure(error.localizedDescription)
        }
        
        isTestingConnection = false
    }
    
    private func saveConfiguration() {
        // Trim whitespace from URL and API key
        let trimmedURL = barcodeBuddyURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = barcodeBuddyAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        serverProfile.barcodeBuddyURL = trimmedURL.isEmpty ? nil : trimmedURL
        serverProfile.barcodeBuddyAPIKey = trimmedAPIKey.isEmpty ? nil : trimmedAPIKey
        
        try? modelContext.save()
        dismiss()
    }
    
    private func clearConfiguration() {
        serverProfile.barcodeBuddyURL = nil
        serverProfile.barcodeBuddyAPIKey = nil
        barcodeBuddyURL = ""
        barcodeBuddyAPIKey = ""
        testResult = nil
        
        try? modelContext.save()
    }
}
