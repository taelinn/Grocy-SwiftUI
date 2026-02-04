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

    @Query var mdQuantityUnits: MDQuantityUnits

    var recipe: Recipe

    @State private var page = WebPage()
    let blank = URL(string: "about:blank")!

    @State private var desiredServings: Double = 1.0

    private let dataToUpdate: [ObjectEntities] = [.quantity_units, .recipes_pos_resolved]
    private let additionalDataToUpdate: [AdditionalEntities] = []
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate, additionalObjects: additionalDataToUpdate)
    }

    var groupedRecipes: [String: [RecipePosResolvedElement]] {
        let sortDescriptor = SortDescriptor<RecipePosResolvedElement>(\.ingredientGroup)
        let predicate = #Predicate<RecipePosResolvedElement> { recipePos in
            recipePos.recipeID == recipe.id
        }

        let descriptor = FetchDescriptor<RecipePosResolvedElement>(
            predicate: predicate,
            sortBy: [sortDescriptor]
        )

        let matchingRecipes = (try? modelContext.fetch(descriptor)) ?? []

        var groupedRecipes: [String: [RecipePosResolvedElement]] = [:]
        for recipePos in matchingRecipes {
            let ingredientGroup = recipePos.ingredientGroup ?? ""
            if groupedRecipes[ingredientGroup] == nil {
                groupedRecipes[ingredientGroup] = []
            }
            groupedRecipes[ingredientGroup]?.append(recipePos)
        }
        return groupedRecipes
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
                        Text("")
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
                        Text("")
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
            Section("Ingredients") {
                ForEach(groupedRecipes.sorted(by: { $0.key < $1.key }), id: \.key) { (groupName, recipes) in
                    Section {
                        ForEach(recipes, id: \.id) { recipe in
                            RecipeIngredientRowView(recipePos: recipe, quantityUnit: mdQuantityUnits.first(where: { $0.id == recipe.quID }))
                        }
                    } header: {
                        if !groupName.isEmpty {
                            Text(groupName)
                                .font(.headline)
                                .italic()
                        }
                    }
                }
            }
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
