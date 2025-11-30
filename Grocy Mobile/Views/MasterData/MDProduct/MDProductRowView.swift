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

    var product: MDProduct
    var location: MDLocation?
    var productGroup: MDProductGroup?

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
                if let locationName = location?.name {
                    Text("\(Text("Location")): \(Text(locationName).font(.caption))")
                }
                if let productGroupName = productGroup?.name {
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
            ),
            location: nil,
            productGroup: nil
        )
        MDProductRowView(
            product: MDProduct(
                id: 2,
                name: "Product 2",
                mdProductDescription: "Description",
                productGroupID: 1,
                locationID: 2,
            ),
            location: nil,
            productGroup: nil
        )
    }
}
