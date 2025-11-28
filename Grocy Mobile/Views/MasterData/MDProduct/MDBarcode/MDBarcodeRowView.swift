//
//  MDBarcodeRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 24.10.23.
//

import SwiftData
import SwiftUI

struct MDBarcodeRowView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query(sort: \MDQuantityUnit.id, order: .forward) var mdQuantityUnits: MDQuantityUnits
    @Query(sort: \MDStore.name, order: .forward) var mdStores: MDStores

    var barcode: MDProductBarcode

    var quantityUnit: MDQuantityUnit? {
        mdQuantityUnits.first(where: { $0.id == barcode.quID })
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(barcode.barcode)
                    .font(.title)
            }
            if let amount = barcode.amount {
                Text("\(Text("Amount")): \(amount.formattedAmount) \(amount == 1 ? quantityUnit?.name ?? String(barcode.quID ?? 0) : quantityUnit?.namePlural ?? String(barcode.quID ?? 0))")
                    .font(.caption)
            }
            if let storeName = mdStores.first(where: { $0.id == barcode.storeID })?.name {
                Text("\(Text("Store")): \(storeName)")
                    .font(.caption)
            }
        }
    }
}

#Preview(traits: .previewData) {
    List {
        MDBarcodeRowView(barcode: MDProductBarcode(id: 1, productID: 1, barcode: "123456789"))
        MDBarcodeRowView(barcode: MDProductBarcode(id: 2, productID: 1, barcode: "543242124", quID: 2, amount: 10.0, storeID: 1))
    }
}
