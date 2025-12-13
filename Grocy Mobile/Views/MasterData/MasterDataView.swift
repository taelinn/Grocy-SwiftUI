//
//  MasterDataView.swift
//  Grocy-SwiftUI (iOS)
//
//  Created by Georg Meissner on 13.11.20.
//

import SwiftUI

private enum MasterDataItem: Hashable {
    case products
    case locations
    case stores
    case quantityUnits
    case productGroups
    case chores
    case batteries
    case taskCategories
    case userFields
    case userEntities
}

struct MasterDataView: View {
    @AppStorage("devMode") private var devMode: Bool = false

    var body: some View {
        List {
            NavigationLink(value: MasterDataItem.products) {
                MDCategoryRowView(categoryName: "Products", iconName: MySymbols.product, mdType: MDProduct.self)
            }

            NavigationLink(value: MasterDataItem.locations) {
                MDCategoryRowView(categoryName: "Locations", iconName: MySymbols.location, mdType: MDLocation.self)
            }

            NavigationLink(value: MasterDataItem.stores) {
                MDCategoryRowView(categoryName: "Stores", iconName: MySymbols.store, mdType: MDStore.self)
            }

            NavigationLink(value: MasterDataItem.quantityUnits) {
                MDCategoryRowView(categoryName: "Quantity units", iconName: MySymbols.quantityUnit, mdType: MDQuantityUnit.self)
            }

            NavigationLink(value: MasterDataItem.productGroups) {
                MDCategoryRowView(categoryName: "Product groups", iconName: MySymbols.productGroup, mdType: MDProductGroup.self)
            }
            
            NavigationLink(value: MasterDataItem.chores) {
                MDCategoryRowView(categoryName: "Chores", iconName: MySymbols.chores, mdType: MDChore.self)
            }

            if devMode {
                NavigationLink(value: MasterDataItem.batteries) {
                    Label("Batteries", systemImage: MySymbols.batteries)
                }
            }

            NavigationLink(value: MasterDataItem.taskCategories) {
                MDCategoryRowView(categoryName: "Task categories", iconName: MySymbols.tasks, mdType: MDTaskCategory.self)
            }

            if devMode {
                NavigationLink(value: MasterDataItem.userFields) {
                    Label("Userfields", systemImage: "questionmark")
                }

                NavigationLink(value: MasterDataItem.userEntities) {
                    Label("User entities", systemImage: "questionmark")
                }
            }
        }
        .navigationTitle("Master data")
        .navigationDestination(
            for: MasterDataItem.self,
            destination: { masterDataItem in
                switch masterDataItem {
                case .products:
                    MDProductsView()
                case .locations:
                    MDLocationsView()
                case .stores:
                    MDStoresView()
                case .quantityUnits:
                    MDQuantityUnitsView()
                case .productGroups:
                    MDProductGroupsView()
                case .chores:
                    MDChoresView()
                case .batteries:
                    MDBatteriesView()
                case .taskCategories:
                    MDTaskCategoriesView()
                case .userFields:
                    MDUserFieldsView()
                case .userEntities:
                    MDUserEntitiesView()
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        MasterDataView()
    }
}
