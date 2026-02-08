//
//  BBBarcodeRowView.swift
//  Grocy Mobile
//
//  Individual barcode row view
//

import SwiftUI

struct BBBarcodeRowView: View {
    let barcode: BBUnknownBarcode
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon
            Image(systemName: barcode.isLookedUp ? "barcode" : "questionmark.circle")
                .font(.title2)
                .foregroundStyle(barcode.isLookedUp ? .blue : .orange)
                .frame(width: 40)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Primary text: name if available, otherwise barcode
                Text(barcode.name ?? barcode.barcode)
                    .font(.body)
                    .fontWeight(barcode.name != nil ? .medium : .regular)
                
                // Secondary text
                HStack(spacing: 8) {
                    if barcode.name != nil {
                        Text(barcode.barcode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Unknown product")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if barcode.possibleMatch != nil {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
            }
            
            Spacer()
            
            // Amount badge
            if barcode.amount > 1 {
                Text("\(barcode.amount)×")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
