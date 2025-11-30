//
//  MDBarcodeRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 24.10.23.
//

import SwiftData
import SwiftUI

struct MDBarcodeRowView: View {
    var barcode: MDProductBarcode
    var quantityUnit: MDQuantityUnit?
    var store: MDStore?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(barcode.barcode)
                    .font(.title)
            }
            if let amount = barcode.amount {
                Text("\(Text("Amount")): \(amount.formattedAmount) \(quantityUnit?.getName(amount: amount) ?? String(barcode.quID ?? 0))")
                    .font(.caption)
            }
            if let storeName = store?.name {
                Text("\(Text("Store")): \(storeName)")
                    .font(.caption)
            }
        }
    }
}

#Preview(traits: .previewData) {
    List {
        MDBarcodeRowView(barcode: MDProductBarcode(id: 1, productID: 1, barcode: "123456789"), quantityUnit: nil, store: nil)
        MDBarcodeRowView(barcode: MDProductBarcode(id: 2, productID: 1, barcode: "543242214", quID: 2, amount: 1.0, storeID: 1), quantityUnit: nil, store: nil)
        MDBarcodeRowView(barcode: MDProductBarcode(id: 3, productID: 1, barcode: "543242124", quID: 2, amount: 10.0, storeID: 2), quantityUnit: nil, store: nil)
    }
}
