//
//  RecipeRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 02.12.22.
//

import SwiftUI

struct RecipeRowView: View {
    var recipe: Recipe
    var fulfillment: RecipeFulfilment?

    var body: some View {
        VStack(alignment: .leading) {
            if let pictureFileName = recipe.pictureFileName {
                PictureView(pictureFileName: pictureFileName, pictureType: .recipePictures)
                    .clipShape(.rect(cornerRadius: 5.0))
                    .frame(maxWidth: 200.0, maxHeight: 200.0)
            } else {
                ProgressView()
                    .frame(maxWidth: 200.0, maxHeight: 200.0)
            }
            Text(recipe.name)
                .font(.headline)
            HStack(alignment: .center) {
                VStack(alignment: .center) {
                    Text("\(fulfillment?.dueScore ?? 0)")
                        .font(.title3)
                    Text("Due score")
                        .font(.caption)
                }
                Spacer()
                if fulfillment?.needFulfilled == 1 {
                    HStack {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                        Text("Enough in stock")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if fulfillment?.needFulfilledWithShoppingList == 1 {
                    HStack {
                        Image(systemName: "exclamationmark")
                            .foregroundStyle(.yellow)
                        Text("Not enough in stock, \(fulfillment?.missingProductsCount ?? 0) ingredient missing but already on the shopping list")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark")
                            .foregroundStyle(.red)
                        Text("Not enough in stock, \(fulfillment?.missingProductsCount ?? 0) ingredient missing")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(8.0)
        .cornerRadius(5.0)
        .border(.primary)
    }
}

#Preview(traits: .previewData) {
    List {
        RecipeRowView(recipe: Recipe(id: 1, name: "Recipe"), fulfillment: RecipeFulfilment(recipeID: 1, needFulfilled: 1, dueScore: 10))
        RecipeRowView(recipe: Recipe(id: 2), fulfillment: RecipeFulfilment(recipeID: 2, needFulfilledWithShoppingList: 1, missingProductsCount: 5))
        RecipeRowView(recipe: Recipe(id: 3), fulfillment: RecipeFulfilment(recipeID: 3))
    }
}
