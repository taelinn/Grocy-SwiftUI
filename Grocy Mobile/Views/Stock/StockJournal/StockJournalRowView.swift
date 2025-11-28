//
//  StockJournalRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 20.10.23.
//

import SwiftData
import SwiftUI

struct StockJournalRowView: View {
    var journalEntry: StockJournalEntry
    var product: MDProduct?
    var location: MDLocation?
    var quantityUnit: MDQuantityUnit?
    var grocyUser: GrocyUser?

    @AppStorage("localizationKey") var localizationKey: String = "en"

    var body: some View {
        VStack(alignment: .leading) {
            Text(product?.name ?? "Name Error")
                .font(.title)
                .strikethrough(journalEntry.undone == 1, color: .primary)
            if journalEntry.undone == 1 {
                if let date = getDateFromTimestamp(journalEntry.undoneTimestamp ?? "") {
                    HStack(alignment: .bottom) {
                        Text("\(Text("Undone on")) \(formatDateAsString(date, showTime: true, localizationKey: localizationKey) ?? "")")
                            .font(.caption)
                        Text(getRelativeDateAsText(date, localizationKey: localizationKey) ?? "")
                            .font(.caption)
                            .italic()
                    }
                    .foregroundStyle(journalEntry.undone == 1 ? Color.gray : Color.primary)
                }
            }
            Group {
                Text("\(Text("Amount")): \(journalEntry.amount.formattedAmount) \(quantityUnit?.getName(amount: journalEntry.amount) ?? "")")
                Text("\(Text("Transaction time")): \(formatTimestampOutput(journalEntry.rowCreatedTimestamp, localizationKey: localizationKey) ?? "")")
                Text("\(Text("Transaction type")): \(Text(journalEntry.transactionType.localizedName))")
                    .font(.caption)
                Text("\(Text("Location")): \(location?.name ?? "Location Error")")
                Text("\(Text("Done by")): \(grocyUser?.displayName ?? "Username Error")")
                if let note = journalEntry.note {
                    Text("\(Text("Note")): \(note)")
                }
            }
            .foregroundStyle(journalEntry.undone == 1 ? Color.gray : Color.primary)
            .font(.caption)
        }
    }
}

#Preview(traits: .previewData) {
    let container = PreviewContainer.shared
    let context = ModelContext(container)

    // Fetch one object from the preview store
    let descriptor = FetchDescriptor<StockJournalEntry>()
    let journalEntry = (try? context.fetch(descriptor))?.randomElement()
    
//    let productDescriptor = FetchDescriptor<MDProduct>(predicate: #Predicate<MDProduct> { $0.id == journalEntry?.productID })
//    let product = (try? context.fetch(productDescriptor))?.first

    List {
        if let journalEntry {
            StockJournalRowView(journalEntry: journalEntry, product: MDProduct())
        }
    }
}
