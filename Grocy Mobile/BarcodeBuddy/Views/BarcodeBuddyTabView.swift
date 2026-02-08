//
//  BarcodeBuddyTabView.swift
//  Grocy Mobile
//
//  Main BarcodeBuddy tab view
//

import SwiftUI
import SwiftData

struct BarcodeBuddyTabView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel = BarcodeBuddyViewModel()
    @State private var showingSettings = false
    @State private var selectedSegment = 0
    
    private var currentProfile: ServerProfile? {
        grocyVM.selectedServerProfile
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let profile = currentProfile, profile.hasBBConfigured {
                    VStack(spacing: 0) {
                        // Segment picker
                        Picker("View", selection: $selectedSegment) {
                            Text("Barcodes").tag(0)
                            Text("History").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        
                        // Content
                        if selectedSegment == 0 {
                            BBBarcodeListView(viewModel: viewModel)
                        } else {
                            BBLogListView(viewModel: viewModel)
                        }
                    }
                    .task {
                        configureViewModel()
                        await viewModel.refresh()
                    }
                    .refreshable {
                        if selectedSegment == 0 {
                            await viewModel.fetchUnknownBarcodes()
                        } else {
                            await viewModel.fetchBarcodeLogs()
                        }
                    }
                } else {
                    // Not configured
                    ContentUnavailableView {
                        Label("BarcodeBuddy Not Configured", systemImage: "barcode.viewfinder")
                    } description: {
                        Text("Connect to your BarcodeBuddy server to view and resolve unresolved barcodes")
                    } actions: {
                        if currentProfile != nil {
                            Button {
                                showingSettings = true
                            } label: {
                                Text("Setup BarcodeBuddy")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("Barcodes")
            .toolbar {
                if currentProfile?.hasBBConfigured == true {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                    
                    ToolbarItem(placement: .automatic) {
                        Button {
                            Task {
                                await viewModel.refresh()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                if let profile = currentProfile {
                    NavigationStack {
                        BBSettingsView(serverProfile: profile)
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func configureViewModel() {
        guard let profile = currentProfile,
              let url = profile.barcodeBuddyURL,
              let key = profile.barcodeBuddyAPIKey else {
            return
        }
        viewModel.configure(serverURL: url, apiKey: key, modelContext: modelContext)
    }
}
