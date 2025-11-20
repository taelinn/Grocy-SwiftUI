//
//  ServerSelectionView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 17.11.25.
//

import SwiftData
import SwiftUI

struct ServerSelectionView: View {
    @Environment(\.profileModelContext) private var profileModelContext
    @State private var showAddServer: Bool = false
    @State private var serverProfiles: [ServerProfile] = []

    private func fetchServerProfiles() {
        guard let modelContext = profileModelContext else { return }
        let descriptor = FetchDescriptor<ServerProfile>(sortBy: [SortDescriptor(\.id, order: .forward)])
        serverProfiles = (try? modelContext.fetch(descriptor)) ?? []
    }

    var selectedServerProfile: ServerProfile? {
        return serverProfiles.first(where: { $0.isActive == true })
    }

    var body: some View {
        List {
            ForEach(serverProfiles, id: \.id) { serverProfile in
                Button(
                    action: {
                        setActiveProfile(serverProfile)
                    },
                    label: {
                        ServerProfileRowView(profile: serverProfile)
                    }
                )
                .foregroundStyle(.primary)
                .contextMenu(menuItems: {
                    contextMenuContent(for: serverProfile)
                })
            }
            .onDelete(perform: deleteProfiles)
        }
        .navigationTitle("Own server")
        .onAppear {
            fetchServerProfiles()
            if serverProfiles.isEmpty {
                showAddServer.toggle()
            }
        }
        .toolbar(content: {
            ToolbarItem(
                placement: .primaryAction,
                content: {
                    Button(
                        action: {
                            showAddServer.toggle()
                        },
                        label: {
                            Image(systemName: MySymbols.new)
                        }
                    )
                }
            )
        })
        .safeAreaBar(
            edge: .bottom,
            content: {
                if selectedServerProfile != nil {
                    NavigationLink(
                        value: LoginDestination(type: .ownServer),
                        label: {
                            Label("Login", systemImage: MySymbols.login)
                        }
                    )
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .padding()
                    .glassEffect(.regular.tint(.green).interactive())
                }
            }
        )
        #if os(iOS)
            .sheet(
                isPresented: $showAddServer,
                content: {
                    NavigationStack {
                        ServerProfileFormView()
                    }
                    .environment(\.profileModelContext, profileModelContext)
                }
            )
        #else
            .sheet(
                isPresented: $showAddServer,
                content: {
                    ServerProfileFormView()
                        .environment(\.profileModelContext, profileModelContext)
                }
            )
        #endif
    }

    private func setActiveProfile(_ profile: ServerProfile) {
        serverProfiles.forEach { $0.isActive = false }
        profile.isActive = true
    }

    private func deleteProfiles(at offsets: IndexSet) {
        for index in offsets {
            profileModelContext?.delete(serverProfiles[index])
        }
    }

    @ViewBuilder
    private func contextMenuContent(for profile: ServerProfile) -> some View {
        NavigationLink(
            value: profile,
            label: {
                Label("Edit", systemImage: MySymbols.edit)
            }
        )
        Button(action: {
            duplicateProfile(profile)
        }, label: {
            Label("Duplicate", systemImage: MySymbols.duplicate)
        })
    }

    private func duplicateProfile(_ profile: ServerProfile) {
        let newServerProfile = ServerProfile(
            name: profile.name + " (Duplicate)",
            grocyServerURL: profile.grocyServerURL,
            grocyAPIKey: profile.grocyAPIKey,
            useHassIngress: profile.useHassIngress,
            hassToken: profile.hassToken,
            customHeaders: profile.customHeaders ?? [],
            isActive: false
        )
        profileModelContext?.insert(newServerProfile)
        _ = try? profileModelContext?.save()
    }
}
