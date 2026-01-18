//
//  RecipeFormView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 12.01.26.
//

import SwiftData
import SwiftUI

struct RecipeFormView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query var mdProducts: MDProducts
    @Query var recipes: Recipes

    @Environment(\.dismiss) var dismiss

    @State private var isProcessing: Bool = false
    @State private var isSuccessful: Bool? = nil
    @State private var errorMessage: String? = nil
    @State private var isPreparationExpanded: Bool = false
    
    @State private var showAddRecipeIngredient: Bool = false

    var existingRecipe: Recipe?
    @State var recipe: Recipe

    @State private var isFormCorrect: Bool = false
    private func checkFormCorrect() -> Bool {
        let foundRecipe = recipes.first(where: { $0.name == recipe.name })
        return !(recipe.name.isEmpty || (foundRecipe != nil && foundRecipe!.id != recipe.id)) && recipe.baseServings > 0
    }

    init(existingRecipe: Recipe? = nil) {
        self.existingRecipe = existingRecipe
        self.recipe = existingRecipe ?? Recipe()
    }

    private let dataToUpdate: [ObjectEntities] = [.products]
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate)
    }

    private func finishForm() {
        dismiss()
    }

    private func saveRecipe() async {
        if recipe.id == -1 {
            do {
                recipe.id = try grocyVM.findNextID(.recipes)
            } catch {
                GrocyLogger.error("Failed to get next ID: \(error)")
                return
            }
        }
        isProcessing = true
        isSuccessful = nil
        do {
            try recipe.modelContext?.save()
            if existingRecipe == nil {
                _ = try await grocyVM.postMDObject(object: .recipes, content: recipe)
            } else {
                try await grocyVM.putMDObjectWithID(object: .recipes, id: recipe.id, content: recipe)
            }
            GrocyLogger.info("Recipe \(recipe.name) successful.")
            await updateData()
            isSuccessful = true
        } catch {
            GrocyLogger.error("Recipe \(recipe.name) failed. \(error)")
            isSuccessful = false
            if let apiError = error as? APIError {
                errorMessage = apiError.displayMessage
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isProcessing = false
    }

    var body: some View {
        Form {
            if isSuccessful == false, let errorMessage = errorMessage {
                ErrorMessageView(errorMessage: errorMessage)
            }
            MyTextField(
                textToEdit: $recipe.name,
                description: "Name",
                prompt: "Required",
                isCorrect: $isFormCorrect,
                leadingIcon: MySymbols.name,
                emptyMessage: "A name is required",
                errorMessage: "Name already exists"
            )
            .onChange(of: recipe.name) {
                isFormCorrect = checkFormCorrect()
            }
            MyDoubleStepper(amount: $recipe.baseServings, description: "Servings", descriptionInfo: "The ingredients listed here result in this amount of servings", minAmount: 0.0000001, systemImage: MySymbols.amount)

            MyToggle(
                isOn: $recipe.notCheckShoppinglist,
                description: "Do not check against the shopping list when adding missing items to it",
                descriptionInfo:
                    "By default the amount to be added to the shopping list is \"needed amount - stock amount - shopping list amount\" - when this is enabled, it is only checked against the stock amount, not against what is already on the shopping list",
                icon: MySymbols.shoppingList,
            )

            ProductField(productID: $recipe.productID, description: "Produces product", descriptionInfo: "When a product is selected, one unit (per serving in stock quantity unit) will be added to stock on consuming this recipe")

            if existingRecipe != nil {
                Section(
                    content: {
//                        ForEach(quConversions, id: \.id) { quConversion in
//                            NavigationLink(value: quConversion) {
//                                Text("\(quConversion.factor.formattedAmount) \(mdQuantityUnits.first(where: { $0.id == quConversion.toQuID })?.name ?? "\(quConversion.id)")")
//                            }
//                            .swipeActions(
//                                edge: .trailing,
//                                allowsFullSwipe: true,
//                                content: {
//                                    Button(
//                                        role: .destructive,
//                                        action: { markDeleteQUConversion(conversion: quConversion) },
//                                        label: { Label("Delete", systemImage: MySymbols.delete) }
//                                    )
//                                }
//                            )
//                        }
                    },
                    header: {
                        VStack(alignment: .leading) {
                            HStack(alignment: .top) {
                                Text("Ingredients list")
                                Spacer()
                                Button(
                                    action: {
                                        showAddRecipeIngredient.toggle()
                                    },
                                    label: {
                                        Label("Add", systemImage: MySymbols.new)
                                    }
                                )
                            }
//                            Text("1 \(quantityUnit.name) is the same as...")
//                                .italic()
                        }
                    }
                )

                Section("Included recipes") {

                }

                Section("Picture") {

                }
            }

            Section(isExpanded: $isPreparationExpanded) {
                MyTextEditor(textToEdit: $recipe.recipeDescription, description: "Preparation", leadingIcon: MySymbols.description)
            } header: {

                Button(action: {
                    withAnimation {
                        isPreparationExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("Preparation")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(
                                !isPreparationExpanded ? Angle(degrees: 0) : Angle(degrees: 90)
                            )
                            .frame(width: 20, height: 20)
                    }
                }
                .foregroundStyle(.secondary)
                .font(.headline)
            }
        }
        .formStyle(.grouped)
        .task {
            await updateData()
            self.isFormCorrect = checkFormCorrect()
        }
        .navigationTitle(existingRecipe == nil ? "Create recipe" : "Edit recipe")
        .toolbar(content: {
            if existingRecipe == nil {
                ToolbarItem(
                    placement: .cancellationAction,
                    content: {
                        Button(
                            role: .cancel,
                            action: {
                                finishForm()
                            }
                        )
                        .keyboardShortcut(.cancelAction)
                    }
                )
            }
            ToolbarItem(
                placement: .confirmationAction,
                content: {
                    Button(
                        role: .confirm,
                        action: {
                            Task {
                                await saveRecipe()
                            }
                        },
                        label: {
                            if !isProcessing {
                                Label("Save", systemImage: MySymbols.save)
                                    .labelStyle(.titleAndIcon)
                            } else {
                                ProgressView().progressViewStyle(.circular)
                            }
                        }
                    )
                    .disabled(!isFormCorrect || isProcessing)
                    .keyboardShortcut(.defaultAction)
                }
            )
        })
        .onChange(of: isSuccessful) {
            if isSuccessful == true {
                finishForm()
            }
        }
        .sensoryFeedback(.success, trigger: isSuccessful == true)
        .sensoryFeedback(.error, trigger: isSuccessful == false)
    }
}

#Preview("Create", traits: .previewData) {
    NavigationStack {
        RecipeFormView()
    }
}

#Preview("Edit", traits: .previewData) {
    NavigationStack {
        RecipeFormView(existingRecipe: Recipe(name: "Recipe"))
    }
}
