//
//  RecipeView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 23.11.23.
//

import SwiftData
import SwiftUI
import WebKit

struct RecipeView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(\.modelContext) private var modelContext

    @Query var quantityUnits: MDQuantityUnits

    var recipe: Recipe

    @State private var page = WebPage()
    let blank = URL(string: "about:blank")!

    @State private var desiredServings: Double = 1.0

    private let dataToUpdate: [ObjectEntities] = [.quantity_units, .recipes_pos_resolved]
    private let additionalDataToUpdate: [AdditionalEntities] = []
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate, additionalObjects: additionalDataToUpdate)
    }

    var recipePosResolved: [RecipePosResolvedElement] {
        let sortDescriptor = SortDescriptor<RecipePosResolvedElement>(\.productName)
        let predicate = #Predicate<RecipePosResolvedElement> { pos in
            pos.recipeID == recipe.id
        }

        let descriptor = FetchDescriptor<RecipePosResolvedElement>(
            predicate: predicate,
            sortBy: [sortDescriptor]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var posResCount: Int {
        var descriptor = FetchDescriptor<RecipePosResolvedElement>(
            sortBy: []
        )
        descriptor.fetchLimit = 0

        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    var body: some View {
        //        ScrollView(.vertical) {
        //            VStack(alignment: .leading) {
        //                if let pictureFileName = recipe.pictureFileName {
        //                    PictureView(pictureFileName: pictureFileName, pictureType: .recipePictures)
        //                        .backgroundExtensionEffect()
        //                }

        List {
            Section {
                //                MyDoubleStepper(amount: $recipe.desiredServings, description: "Desired servings", systemImage: MySymbols.amount)
                LabeledContent(
                    content: {
                        Text("123")
                        //                    Text("\(recipe.)")
                    },
                    label: {
                        HStack {
                            Label("kcal", systemImage: MySymbols.energy)
                            FieldDescription(description: "per serving")
                        }
                    }
                )
                .foregroundStyle(.primary)
                LabeledContent(
                    content: {
                        Text("123")
                        //                    Text("\(recipe.)")
                    },
                    label: {
                        HStack {
                            Label("Costs", systemImage: MySymbols.price)
                            FieldDescription(description: "Based on the prices of the default consume rule (Opened first, then first due first, then first in first out) for in stock ingredients and on the last price for missing ones")
                        }
                    }
                )
                .foregroundStyle(.primary)
            }
            //            Section("Ingredients") {
            //                ForEach(recipePosResolved, id: \.id) { pos in
            //                    RecipeIngredientRowView(recipePos: pos, quantityUnit: quantityUnits.first(where: { $0.id == pos.quID }))
            //                }
            //            }
            Section(
                "Preparation",
                content: {
                    WebView(page)
                        .aspectRatio(contentMode: .fit)
                        .onAppear {
                            page.load(html: recipe.recipeDescription, baseURL: blank)
                        }
                }
            )
        }
        .navigationTitle(recipe.name)
        .task {
            await updateData()
        }
    }
}

#Preview {
    NavigationStack {
        RecipeView(recipe: Recipe(name: "Recipe 1", recipeDescription: "<h1>Hello</h1>"))
    }
}
