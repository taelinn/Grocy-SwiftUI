//
//  RecipeIngredientRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 09.01.26.
//

import SwiftUI

struct RecipeIngredientRowView: View {
    var recipePos: RecipePosResolvedElement

    var quantityUnits: MDQuantityUnits

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(recipePos.recipeAmount.formattedAmount) \(recipePos.productName)")
                .font(.title2)
            if recipePos.missingAmount == 0.0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
//                    Text("\(Text("Enough in stock")) (\(recipePos.stockAmount.formattedAmount) \(quantityUnit?.name ?? ""))")
                }
            } else {
                HStack {
                    if recipePos.amountOnShoppingList > 0.0 {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.yellow)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    Text("Not enough in stock, \(recipePos.missingAmount.formattedAmount) missing, \(recipePos.amountOnShoppingList.formattedAmount) already on shopping list")
                }
            }
        }
    }
}

//#Preview(traits: .previewData) {
//    List {
//        RecipeIngredientRowView(recipePos: RecipePosResolvedElement(quID: 1, productName: "Product name"))
//    }
//}
