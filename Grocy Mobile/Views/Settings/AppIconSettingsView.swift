//
//  AppIconSettingsView.swift
//  Grocy Mobile
//
//  App icon selection view
//

import SwiftUI

struct AppIconSettingsView: View {
    @State private var iconManager = AppIconManager.shared
    @State private var isChangingIcon = false
    @State private var showError = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            Section {
                ForEach(AppIconManager.AppIcon.allCases) { icon in
                    Button {
                        changeIcon(to: icon)
                    } label: {
                        HStack(spacing: 16) {
                            // Icon preview
                            Image(icon.previewImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(icon.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                if icon == iconManager.currentIcon {
                                    Text("Current")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if icon == iconManager.currentIcon {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(isChangingIcon)
                }
            } header: {
                Text("Choose your app icon")
            } footer: {
                Text("The app icon will change immediately. You may see a brief confirmation dialog from iOS.")
            }
        }
        .navigationTitle("App Icon")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .overlay {
            if isChangingIcon {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }
    
    private func changeIcon(to icon: AppIconManager.AppIcon) {
        guard icon != iconManager.currentIcon else { return }
        
        isChangingIcon = true
        
        Task {
            do {
                try await iconManager.setIcon(icon)
                // Small delay to let the system update
                try? await Task.sleep(for: .milliseconds(500))
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                GrocyLogger.error("Failed to change app icon: \(error)")
            }
            isChangingIcon = false
        }
    }
}

#Preview {
    NavigationStack {
        AppIconSettingsView()
    }
}
