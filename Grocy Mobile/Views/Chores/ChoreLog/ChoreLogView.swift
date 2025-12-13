//
//  ChoreLogView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 11.12.25.
//

import SwiftData
import SwiftUI

struct ChoreLogView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @Query var chores: Chores
    @Query var users: GrocyUsers

    @State private var searchString: String = ""

    @State private var filteredChoreID: Int?
    @State private var filteredUserID: Int?
    @State private var showingFilterSheet = false
    @State private var isFirstShown: Bool = true

    var choreID: Int? = nil
    var isPopup: Bool = false

    // Fetch the data with a dynamic predicate
    var choreLog: ChoreLog {
        let sortDescriptor = SortDescriptor<ChoreLogEntry>(\.rowCreatedTimestamp, order: .reverse)
        var predicates: [Predicate<ChoreLogEntry>] = []

        // Find matching product IDs for search string
        var matchingChoreIDs: [Int]? {
            let chorePredicate =
                searchString.isEmpty
                ? nil
                : #Predicate<Chore> { chore in
                    chore.choreName.localizedStandardContains(searchString)
                }
            let choreDescriptor = FetchDescriptor<Chore>(predicate: chorePredicate)
            let matchingChores = try? modelContext.fetch(choreDescriptor)
            return matchingChores?.map(\.id) ?? []
        }

        // Chore search predicate
        if !searchString.isEmpty, let matchingChoreIDs {
            let searchPredicate = #Predicate<ChoreLogEntry> { entry in
                matchingChoreIDs.contains(entry.choreID)
            }
            predicates.append(searchPredicate)
        }

        // Filtered user predicate
        if let filteredUserID = filteredUserID {
            let choreLogPredicate = #Predicate<ChoreLogEntry> { entry in
                entry.doneByUserID == filteredUserID
            }
            predicates.append(choreLogPredicate)
        }

        // Filtered chore predicate
        if let filteredChoreID = filteredChoreID {
            let choreLogPredicate = #Predicate<ChoreLogEntry> { entry in
                entry.choreID == filteredChoreID
            }
            predicates.append(choreLogPredicate)
        }

        // Combine predicates
        let finalPredicate = predicates.reduce(nil as Predicate<ChoreLogEntry>?) { (result: Predicate<ChoreLogEntry>?, predicate: Predicate<ChoreLogEntry>) in
            if let existing = result {
                return #Predicate<ChoreLogEntry> {
                    existing.evaluate($0) && predicate.evaluate($0)
                }
            }
            return predicate
        }

        let descriptor = FetchDescriptor<ChoreLogEntry>(
            predicate: finalPredicate,
            sortBy: [sortDescriptor]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // Get the unfiltered count without fetching any data
    var choreLogCount: Int {
        var descriptor = FetchDescriptor<ChoreLogEntry>(
            sortBy: []
        )
        descriptor.fetchLimit = 0

        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private let dataToUpdate: [ObjectEntities] = [.chores, .chores_log]
    private let additionalDataToUpdate: [AdditionalEntities] = [.users]

    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate, additionalObjects: additionalDataToUpdate)
    }

    private func undoExecution(choreLogEntry: ChoreLogEntry) async {
        do {
            try await grocyVM.undoChoreWithID(id: choreLogEntry.id)
            GrocyLogger.info("Undo chore execution \(choreLogEntry.id) successful.")
            await grocyVM.requestData(objects: [.chores_log])
        } catch {
            GrocyLogger.error("Undo chore execution failed. \(error)")
        }
    }

    var body: some View {
        List {
            if grocyVM.failedToLoadObjects.filter({ dataToUpdate.contains($0) }).count > 0 {
                ServerProblemView()
            } else if choreLogCount == 0 {
                ContentUnavailableView("No chore entries found.", systemImage: MySymbols.chores)
            } else if choreLog.isEmpty {
                ContentUnavailableView.search
            }
            ForEach(choreLog, id: \.id) { (choreLogEntry: ChoreLogEntry) in
                ChoreLogRowView(choreLogEntry: choreLogEntry, chore: chores.first(where: { $0.id == choreLogEntry.choreID }), user: users.first(where: { $0.id == choreLogEntry.doneByUserID }))
                    .swipeActions(
                        edge: .leading,
                        allowsFullSwipe: true,
                        content: {
                            Button(
                                action: {
                                    Task {
                                        await undoExecution(choreLogEntry: choreLogEntry)
                                    }
                                },
                                label: {
                                    Label("Undo chore execution", systemImage: MySymbols.undo)
                                }
                            )
                            .disabled(choreLogEntry.undone)
                        }
                    )
            }
        }
        .navigationTitle("Stock journal")
        .toolbar {
            if isPopup {
                ToolbarItem(
                    placement: .cancellationAction,
                    content: {
                        Button(
                            role: .cancel,
                            action: {
                                dismiss()
                            }
                        )
                        .keyboardShortcut(.cancelAction)
                    }
                )
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showingFilterSheet = true }) {
                    Label("Filter", systemImage: MySymbols.filter)
                }
            }
            #if os(iOS)
                ToolbarSpacer(.flexible, placement: .bottomBar)
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
            #endif
        }
        .searchable(
            text: $searchString,
            placement: .toolbar,
        )
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                ChoreLogFilterView(
                    filteredChoreID: $filteredChoreID,
                    filteredUserID: $filteredUserID,
                )
                .navigationTitle("Filter")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(
                        placement: .confirmationAction,
                        content: {
                            Button(
                                role: .confirm,
                                action: {
                                    showingFilterSheet = false
                                }
                            )
                        }
                    )
                    ToolbarItem(
                        placement: .cancellationAction,
                        content: {
                            Button(
                                role: .destructive,
                                action: {
                                    filteredChoreID = nil
                                    filteredUserID = nil
                                    showingFilterSheet = false
                                }
                            )
                        }
                    )
                }
            }
            .presentationDetents([.medium])
        }
        .refreshable {
            await updateData()
        }
        .task {
            await updateData()
            if isFirstShown {
                filteredChoreID = choreID
                isFirstShown = false
            }
        }
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        ChoreLogView()
    }
}
