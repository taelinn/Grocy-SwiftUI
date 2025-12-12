//
//  ChoresView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 09.12.25.
//

import SwiftData
import SwiftUI

enum ChoresSortOption: Hashable, Sendable {
    case byName
    case byNextEstimatedTracking
    case byLastTracked
    case byUser
}

struct ChoresView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.modelContext) private var modelContext

    @State private var searchString: String = ""
    @State private var showingFilterSheet = false
    @State private var showChoreLog = false
    @State private var filteredStatus: ChoreStatus = .all
    @State private var filteredUserID: Int? = nil
    @State private var sortOption: ChoresSortOption = .byName
    @State private var sortOrder: SortOrder = .forward

    @Query var grocyUsers: GrocyUsers
    @Query var userSettingsList: GrocyUserSettingsList
    var userSettings: GrocyUserSettings? {
        return userSettingsList.first
    }

    var chores: Chores {
        let sortDescriptor = SortDescriptor<Chore>(\.id)
        let predicate = #Predicate<Chore> { chore in
            searchString.isEmpty || chore.choreName.localizedStandardContains(searchString)
        }

        let descriptor = FetchDescriptor<Chore>(
            predicate: predicate,
            sortBy: [sortDescriptor]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var choresCount: Int {
        var descriptor = FetchDescriptor<Chore>(
            sortBy: []
        )
        descriptor.fetchLimit = 0

        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    private let dataToUpdate: [ObjectEntities] = []
    private let additionalDataToUpdate: [AdditionalEntities] = [.chores, .current_user, .users]
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate, additionalObjects: additionalDataToUpdate)
    }

    var filteredChores: [Chore] {
        chores
            .filter { filteredUserID == nil || $0.nextExecutionAssignedToUserID == filteredUserID }
            .filter { matchesFilter($0) }
    }

    var choreCounts: [ChoreStatus: Int] {
        Dictionary(
            uniqueKeysWithValues: ChoreStatus.allCases.map { status in
                (status, chores.count(where: { matchesFilter($0, for: status) }))
            }
        )
    }

    func matchesFilter(_ chore: Chore, for status: ChoreStatus? = nil) -> Bool {
        let targetStatus = status ?? filteredStatus

        switch targetStatus {
        case .all:
            return true

        case .assignedToMe:
            return chore.nextExecutionAssignedToUserID != nil && chore.nextExecutionAssignedToUserID == grocyVM.currentUser?.id

        case .overdue:
            return daysDifference(for: chore.nextEstimatedExecutionTime) ?? 0 < 0

        case .dueToday:
            return daysDifference(for: chore.nextEstimatedExecutionTime) == 0

        case .dueSoon:
            guard let diff = daysDifference(for: chore.nextEstimatedExecutionTime) else { return false }
            return (0...(userSettings?.choresDueSoonDays ?? 5)).contains(diff)
        }
    }

    private func backgroundColorForChore(_ chore: Chore) -> Color? {
        guard let diff = daysDifference(for: chore.nextEstimatedExecutionTime) else { return nil }

        switch diff {
        case ..<0:
            return Color(.GrocyColors.grocyRedBackground)
        case 0:
            return Color(.GrocyColors.grocyBlueBackground)
        case 0...(userSettings?.choresDueSoonDays ?? 5):
            return Color(.GrocyColors.grocyYellowBackground)
        default:
            return nil
        }
    }

    var sortComparator: (Chore, Chore) -> Bool {
        switch sortOption {
        case .byName:
            return { a, b in
                let aName = a.choreName
                let bName = b.choreName
                let comparison = aName.localizedCaseInsensitiveCompare(bName)
                return self.sortOrder == .forward
                    ? comparison == .orderedAscending
                    : comparison == .orderedDescending
            }
        case .byNextEstimatedTracking:
            return { a, b in
                let aAmount = a.nextEstimatedExecutionTime ?? .now
                let bAmount = b.nextEstimatedExecutionTime ?? .now
                return self.sortOrder == .forward
                    ? aAmount < bAmount
                    : aAmount > bAmount
            }
        case .byLastTracked:
            return { a, b in
                let aAmount = a.lastTrackedTime ?? .distantFuture
                let bAmount = b.lastTrackedTime ?? .distantFuture
                return self.sortOrder == .forward
                    ? aAmount < bAmount
                    : aAmount > bAmount
            }
        case .byUser:
            return { a, b in
                let aAmount = a.nextExecutionAssignedToUserID ?? 0
                let bAmount = b.nextExecutionAssignedToUserID ?? 0
                return self.sortOrder == .forward
                    ? aAmount < bAmount
                    : aAmount > bAmount
            }
        }
    }

    var body: some View {
        List {
            Section {
                ChoresFilterActionsView(
                    filteredStatus: $filteredStatus,
                    numOverdue: choreCounts[ChoreStatus.overdue],
                    numDueToday: choreCounts[ChoreStatus.dueToday],
                    numDueSoon: choreCounts[ChoreStatus.dueSoon],
                    numAssignedToMe: choreCounts[ChoreStatus.assignedToMe]
                )
                .listRowInsets(EdgeInsets())
            }

            if grocyVM.failedToLoadObjects.filter({ dataToUpdate.contains($0) }).count > 0 {
                ServerProblemView()
            } else if choresCount == 0 {
                ContentUnavailableView("No chore defined. Please create one.", systemImage: MySymbols.chores)
            } else if chores.isEmpty {
                ContentUnavailableView.search
            }
            ForEach(filteredChores.sorted(by: sortComparator), id: \.id) { chore in
                ChoreRowView(
                    chore: chore,
                    user: grocyUsers.first(where: { $0.id == chore.nextExecutionAssignedToUserID }),
                )
                .listRowBackground(backgroundColorForChore(chore))
            }
        }
        .task {
            await updateData()
        }
        .refreshable {
            await updateData()
        }
        .searchable(
            text: $searchString,
            prompt: "Search"
        )
        .navigationTitle("Chores overview")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { showingFilterSheet = true }) {
                    Label("Filter", systemImage: MySymbols.filter)
                }
                sortGroupMenu
            }
            ToolbarItem(placement: .automatic) {
                Button(
                    action: {
                        showChoreLog.toggle()
                    },
                    label: {
                        Label("Chores journal", systemImage: MySymbols.stockJournal)
                    }
                )
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                ChoresFilterView(filteredStatus: $filteredStatus, filteredUserID: $filteredUserID)
                    .navigationTitle("Filter")
                    .navigationBarTitleDisplayMode(.inline)
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
                                        filteredStatus = .all
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
        .sheet(isPresented: $showChoreLog) {
            NavigationStack {
                ChoreLogView(isPopup: true)
            }
        }
    }

    var sortGroupMenu: some View {
        Menu(
            content: {
                Picker(
                    "Sort category",
                    systemImage: MySymbols.sortCategory,
                    selection: $sortOption,
                    content: {
                        Label("Name", systemImage: MySymbols.product)
                            .labelStyle(.titleAndIcon)
                            .tag(ChoresSortOption.byName)
                        Label("Next estimated tracking", systemImage: MySymbols.date)
                            .labelStyle(.titleAndIcon)
                            .tag(ChoresSortOption.byNextEstimatedTracking)
                        Label("Last tracked", systemImage: MySymbols.date)
                            .labelStyle(.titleAndIcon)
                            .tag(ChoresSortOption.byLastTracked)
                        Label("Assign to", systemImage: MySymbols.user)
                            .labelStyle(.titleAndIcon)
                            .tag(ChoresSortOption.byUser)
                    }
                )
                #if os(iOS)
                    .pickerStyle(.menu)
                #else
                    .pickerStyle(.inline)
                #endif
                Picker(
                    "Sort order",
                    systemImage: MySymbols.sortCategory,
                    selection: $sortOrder,
                    content: {
                        Label("Ascending", systemImage: MySymbols.sortForward)
                            .labelStyle(.titleAndIcon)
                            .tag(SortOrder.forward)
                        Label("Descending", systemImage: MySymbols.sortReverse)
                            .labelStyle(.titleAndIcon)
                            .tag(SortOrder.reverse)
                    }
                )
                #if os(iOS)
                    .pickerStyle(.menu)
                #else
                    .pickerStyle(.inline)
                #endif
            },
            label: {
                Label("Sort", systemImage: MySymbols.sort)
            }
        )
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        ChoresView()
    }
}
