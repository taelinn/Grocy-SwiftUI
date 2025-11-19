//
//  ServerSelectionView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 17.11.25.
//

import SwiftData
import SwiftUI

struct ServerSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ServerProfile.id, order: .forward) private var serverProfiles: [ServerProfile]

    @State private var showAddServer: Bool = false

    var selectedServerProfile: ServerProfile? {
        let descriptor = FetchDescriptor<ServerProfile>(predicate: #Predicate<ServerProfile> { $0.isActive == true })
        return (try? modelContext.fetch(descriptor))?.first
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
                    NavigationLink(
                        value: serverProfile,
                        label: {
                            Label("Edit", systemImage: MySymbols.edit)
                        }
                    )
                })
            }
            .onDelete(perform: deleteProfiles)
        }
        .navigationTitle("Own server")
        .onAppear {
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
                }
            )
        #else
            .sheet(
                isPresented: $showAddServer,
                content: {
                    ServerProfileFormView()
                }
            )
        #endif
    }

    private func setActiveProfile(_ profile: ServerProfile) {
        for p in serverProfiles {
            p.isActive = false
        }
        profile.isActive = true
    }

    private func deleteProfiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(serverProfiles[index])
        }
    }
}
