//
//  MDProductRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 22.10.23.
//

import SwiftData
import SwiftUI

struct MDProductRowView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query(sort: \MDLocation.id, order: .forward) var mdLocations: MDLocations
    @Query(sort: \MDProductGroup.id, order: .forward) var mdProductGroups: MDProductGroups

    var product: MDProduct

    var body: some View {
        HStack {
            if let pictureFileName = product.pictureFileName {
                PictureView(pictureFileName: pictureFileName, pictureType: .productPictures)
                    .clipShape(.rect(cornerRadius: 5.0))
                    .frame(maxWidth: 75.0, maxHeight: 75.0)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text(product.name)
                        .font(.title)
                        .foregroundStyle(product.active ? .primary : .secondary)
                }
                if let locationName = mdLocations.first(where: { $0.id == product.locationID })?.name {
                    Text("\(Text("Location")): \(Text(locationName).font(.caption))")
                }
                if let productGroupName = mdProductGroups.first(where: { $0.id == product.productGroupID })?.name {
                    Text("\(Text("Product group")): \(Text(productGroupName).font(.caption))")
                }
                if !product.mdProductDescription.isEmpty {
                    Text(product.mdProductDescription)
                        .font(.caption)
                        .italic()
                }
            }
        }
    }
}

#Preview(traits: .previewData) {
    List {
        MDProductRowView(
            product: MDProduct(
                id: 1,
                name: "Product",
            )
        )
        MDProductRowView(
            product: MDProduct(
                id: 2,
                name: "Product 2",
                mdProductDescription: "Description",
                productGroupID: 1,
                locationID: 2,
            )
        )
    }
}
