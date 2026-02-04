//
//  RecipePosRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 02.02.26.
//

import SwiftUI

struct RecipeFormIngredientRowView: View {
    var recipePos: RecipePos

    var product: MDProduct?
    var quantityUnit: MDQuantityUnit?

    var body: some View {
        HStack {
            Text(product?.name ?? "")
            Spacer()
            Text("\(recipePos.amount.formattedAmount) \(quantityUnit?.getName(amount: recipePos.amount) ?? "")")
        }
    }
}
