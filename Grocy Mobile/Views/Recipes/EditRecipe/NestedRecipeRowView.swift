//
//  RecipeFormIncludedRecipeRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 04.02.26.
//

import SwiftUI

struct NestedRecipeRowView: View {
    var nesting: RecipeNesting
    var recipe: Recipe?

    var body: some View {
        Text("\(nesting.servings.formattedAmount) \(recipe?.name ?? "")")
    }
}

#Preview {
    List {
        NestedRecipeRowView(nesting: RecipeNesting(), recipe: Recipe(name: "Recipe"))
    }
}
