//
//  RecipesView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 02.12.22.
//

import SwiftData
import SwiftUI

enum RecipeInteraction: Hashable, Identifiable {
    case showRecipe(recipe: Recipe)
    case editRecipe(recipe: Recipe)
    case editIngredient(ingredient: RecipePos, recipe: Recipe)
    case editNesting(nesting: RecipeNesting, recipeID: Int)

    var id: Self { self }
}

@Observable
final class RecipeInteractionNavigationRouter {
    var path: [RecipeInteraction] = []

    func present(_ interaction: RecipeInteraction) {
        path.append(interaction)
    }
}

struct RecipesView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query(sort: \Recipe.name, order: .forward) var recipes: Recipes
    @Query var recipeFulfilments: RecipeFulfilments

    @State private var recipeInteractionRouter = RecipeInteractionNavigationRouter()

    @State private var searchString: String = ""
    @State private var showAddRecipe: Bool = false
    @State private var recipeToDelete: Recipe? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var sortOrder = [KeyPathComparator(\Recipe.name)]

    private let dataToUpdate: [ObjectEntities] = [.recipes, .products]
    private let additionalDataToUpdate: [AdditionalEntities] = [.recipeFulfillments]
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate, additionalObjects: additionalDataToUpdate)
    }

    //    private var gridLayout = [GridItem(.flexible()), GridItem(.flexible())]

    private func deleteItem(itemToDelete: Recipe) {
        recipeToDelete = itemToDelete
        showDeleteConfirmation.toggle()
    }

    private func deleteRecipe(toDelID: Int) async {
        do {
            try await grocyVM.deleteMDObject(object: .recipes, id: toDelID)
            GrocyLogger.info("Deleting recipe was successful.")
            await updateData()
        } catch {
            GrocyLogger.error("Deleting recipe failed. \(error)")
        }
    }

    var filteredRecipes: Recipes {
        recipes
            .filter({
                $0.type == .normal
            })
            .filter({
                searchString.isEmpty ? true : $0.name.localizedCaseInsensitiveContains(searchString)
            })
            .sorted(using: sortOrder)
    }

    var body: some View {
        NavigationStack(path: $recipeInteractionRouter.path) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(filteredRecipes, id: \.id) { recipe in
                        NavigationLink(
                            value: RecipeInteraction.showRecipe(recipe: recipe),
                            label: {
                                RecipeRowView(recipe: recipe, fulfillment: recipeFulfilments.first(where: { $0.recipeID == recipe.id }))
                                    .foregroundStyle(.foreground)
                            }
                        )
                        .contextMenu(menuItems: {
                            Button(
                                action: {
                                    recipeInteractionRouter.present(.editRecipe(recipe: recipe))
                                },
                                label: {
                                    Label("Edit this item", systemImage: MySymbols.edit)
                                }
                            )
                            Button(
                                action: {
                                },
                                label: {
                                    Label("Add to meal plan", systemImage: MySymbols.new)
                                }
                            )
                            Button(
                                role: .destructive,
                                action: {
                                    deleteItem(itemToDelete: recipe)
                                },
                                label: {
                                    Label("Delete this item", systemImage: MySymbols.delete)
                                }
                            )
                            Button(
                                action: {
                                    //                                    recipeInteractionRouter.present(.copyRecipe(recipe: recipe))
                                },
                                label: {
                                    Label("Copy recipe", systemImage: "document.on.document")
                                }
                            )
                        })
                    }
                }
                .padding(8)
            }
            .navigationTitle("Recipes")
            .navigationDestination(for: RecipeInteraction.self) { interaction in
                switch interaction {
                case .showRecipe(let recipe):
                    RecipeView(recipe: recipe)
                        .environment(recipeInteractionRouter)
                case .editRecipe(let recipe):
                    RecipeFormView(existingRecipe: recipe)
                        .environment(recipeInteractionRouter)
                case .editIngredient(let ingredient, let recipe):
                    RecipeIngredientFormView(existingIngredient: ingredient, recipe: recipe)
                        .environment(recipeInteractionRouter)
                case .editNesting(let nesting, let recipeID):
                    NestedRecipeFormView(existingRecipeNesting: nesting, recipeID: recipeID)
                }
            }
            .alert(
                "Are you sure you want to delete recipe \"\(recipeToDelete?.name ?? "")\"?",
                isPresented: $showDeleteConfirmation,
                actions: {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        if let toDelID = recipeToDelete?.id {
                            Task {
                                await deleteRecipe(toDelID: toDelID)
                            }
                        }
                    }
                }
            )
            .sheet(isPresented: $showAddRecipe) {
                NavigationStack {
                    RecipeFormView()
                        .environment(recipeInteractionRouter)
                }
            }
            .refreshable(action: {
                await updateData()
            })
            .task {
                await updateData()
            }
            .searchable(text: $searchString, prompt: "Search")
            .animation(.default, value: recipes.count)
            .toolbar {
                ToolbarItem(
                    placement: .automatic,
                    content: {
                        #if os(macOS)
                            RefreshButton(updateData: { Task { await updateData() } })
                        #endif
                    }
                )
                ToolbarItem(
                    placement: .primaryAction,
                    content: {
                        Button(
                            action: {
                                showAddRecipe = true
                            },
                            label: {
                                Label("Create recipe", systemImage: MySymbols.new)
                            }
                        )
                    }
                )
            }
        }
    }
}

#Preview(traits: .previewData) {
    NavigationStack {
        RecipesView()
    }
}
