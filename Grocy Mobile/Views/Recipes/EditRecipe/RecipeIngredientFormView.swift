//
//  RecipeIngredientFormView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 12.01.26.
//

import SwiftData
import SwiftUI

struct RecipeIngredientFormView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query var mdProducts: MDProducts
    @Query var recipes: Recipes

    @Environment(\.dismiss) var dismiss

    @State private var isProcessing: Bool = false
    @State private var isSuccessful: Bool? = nil
    @State private var errorMessage: String? = nil

    var existingIngredient: RecipePos?
    @State var ingredient: RecipePos

    @State private var isFormCorrect: Bool = false
    private func checkFormCorrect() -> Bool {
        return true
        //        let foundRecipe = recipes.first(where: { $0.name == recipe.name })
        //        return !(ingredient.name.isEmpty || (foundRecipe != nil && foundRecipe!.id != recipe.id)) && recipe.baseServings > 0
    }

    init(existingIngredient: RecipePos? = nil) {
        self.existingIngredient = existingIngredient
        self.ingredient = existingIngredient ?? RecipePos()
    }

    private let dataToUpdate: [ObjectEntities] = [.products]
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate)
    }

    private func finishForm() {
        dismiss()
    }

    private func saveRecipe() async {
        //        if recipe.id == -1 {
        //            do {
        //                recipe.id = try grocyVM.findNextID(.recipes)
        //            } catch {
        //                GrocyLogger.error("Failed to get next ID: \(error)")
        //                return
        //            }
        //        }
        //        isProcessing = true
        //        isSuccessful = nil
        //        do {
        //            try recipe.modelContext?.save()
        //            if existingRecipe == nil {
        //                _ = try await grocyVM.postMDObject(object: .recipes, content: recipe)
        //            } else {
        //                try await grocyVM.putMDObjectWithID(object: .recipes, id: recipe.id, content: recipe)
        //            }
        //            GrocyLogger.info("Recipe \(recipe.name) successful.")
        //            await updateData()
        //            isSuccessful = true
        //        } catch {
        //            GrocyLogger.error("Recipe \(recipe.name) failed. \(error)")
        //            isSuccessful = false
        //            if let apiError = error as? APIError {
        //                errorMessage = apiError.displayMessage
        //            } else {
        //                errorMessage = error.localizedDescription
        //            }
        //        }
        //        isProcessing = false
    }

    var body: some View {
        Form {
            if isSuccessful == false, let errorMessage = errorMessage {
                ErrorMessageView(errorMessage: errorMessage)
            }

            ProductField(productID: $ingredient.productID, description: "Product")

            MyToggle(
                isOn: $ingredient.onlyCheckSingleUnitInStock,
                description: "Only check if any amount is in stock",
                descriptionInfo: "A different amount/unit can then be used below while for stock fulfillment checking it is sufficient when any amount of the product in stock",
                icon: MySymbols.stockOverview
            )

            AmountSelectionView(productID: $ingredient.productID, amount: $ingredient.amount, quantityUnitID: $ingredient.quID)

            MyTextField(
                textToEdit: $ingredient.variableAmount,
                description: "Variable amount",
                isCorrect: .constant(true),
                leadingIcon: MySymbols.amount,
                helpText: "When this is not empty, it will be shown instead of the amount entered above while the amount there will still be used for stock fulfillment checking"
            )

            MyToggle(
                isOn: $ingredient.roundUp,
                description: "Round up quantity amounts to the nearest whole number",
                icon: MySymbols.amount
            )

            MyToggle(
                isOn: $ingredient.notCheckStockFulfillment,
                description: "Disable stock fulfillment checking for this ingredient",
                icon: MySymbols.stockOverview
            )

            MyTextField(
                textToEdit: $ingredient.ingredientGroup,
                description: "Group",
                isCorrect: .constant(true),
                leadingIcon: MySymbols.groupBy,
                helpText: "This will be used as a headline to group ingredients together",
            )
            
            MyTextEditor(textToEdit: $ingredient.note, description: "Note", leadingIcon: MySymbols.description)
            
            MyDoubleStepper(amount: $ingredient.priceFactor, description: "Price factor", descriptionInfo: "The resulting price of this ingredient will be multiplied by this factor", systemImage: MySymbols.price)
        }
        .formStyle(.grouped)
        .task {
            await updateData()
            self.isFormCorrect = checkFormCorrect()
        }
        .navigationTitle(existingIngredient == nil ? "Add recipe ingredient" : "Edit recipe ingredient")
        .toolbar(content: {
            if existingIngredient == nil {
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
        RecipeIngredientFormView()
    }
}

#Preview("Edit", traits: .previewData) {
    NavigationStack {
        RecipeIngredientFormView(existingIngredient: RecipePos())
    }
}
