//
//  StockTableMenuEntriesView.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 07.12.20.
//

import SwiftData
import SwiftUI

struct StockTableMenuEntriesView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    @Environment(StockInteractionNavigationRouter.self) private var stockInteractionRouter

    var stockElement: StockElement
    var quantityUnit: MDQuantityUnit?

    func consumeAsSpoiled() async {
        do {
            try await grocyVM.postStockObject(
                id: stockElement.productID,
                stockModePost: .consume,
                content: ProductConsume(amount: stockElement.amount, transactionType: .consume, spoiled: true, stockEntryID: nil, recipeID: nil, locationID: nil, exactAmount: nil, allowSubproductSubstitution: nil)
            )
            await grocyVM.requestData(additionalObjects: [.stock])
        } catch {
            GrocyLogger.error("Consume all as spoiled failed. \(error)")
        }
    }

    var body: some View {
        Button(
            action: {
                stockInteractionRouter.present(.addToShL(stockElement: stockElement))
            },
            label: {
                Label("Add to shopping list", systemImage: MySymbols.addToShoppingList)
                    .labelStyle(.titleAndIcon)
            }
        )
        Divider()
        Group {
            Button(
                action: {
                    stockInteractionRouter.present(.productPurchase(stockElement: stockElement))
                },
                label: {
                    Label("Purchase", systemImage: MySymbols.purchase)
                        .labelStyle(.titleAndIcon)
                }
            )
            Button(
                action: {
                    stockInteractionRouter.present(.productConsume(stockElement: stockElement))
                },
                label: {
                    Label("Consume", systemImage: MySymbols.consume)
                        .labelStyle(.titleAndIcon)
                }
            )
            Button(
                action: {
                    stockInteractionRouter.present(.productTransfer(stockElement: stockElement))
                },
                label: {
                    Label("Transfer", systemImage: MySymbols.transfer)
                        .labelStyle(.titleAndIcon)
                }
            )
            Button(
                action: {
                    stockInteractionRouter.present(.productInventory(stockElement: stockElement))
                },
                label: {
                    Label("Inventory", systemImage: MySymbols.inventory)
                        .labelStyle(.titleAndIcon)
                }
            )
        }
        Divider()
        Group {
            //            Button(role: .destructive, action: {
            //                Task {
            //                    await consumeAsSpoiled()
            //                }
            //            }, label: {
            //                Label("Consume \(stockElement.amount.formattedAmount) \(quString)", systemImage: MySymbols.clear)
            //            })

            //                Button(action: {
            //                    print("recip")
            //                }, label: {
            //                    Text("Search for recipes which contain this product")
            //                })
        }
        Divider()
        Group {
            Button(
                action: {
                    stockInteractionRouter.present(.productOverview(stockElement: stockElement))
                },
                label: {
                    Label("Product overview", systemImage: MySymbols.info)
                        .labelStyle(.titleAndIcon)
                }
            )
            //            //                Button(action: {
            //            //                    print("Stock entries are not accessed here")
            //            //                }, label: {
            //            //                    Text("Stock entries")
            //            //                })
            Button(
                action: {
                    stockInteractionRouter.present(.productJournal(stockElement: stockElement))
                },
                label: {
                    Label("Stock journal", systemImage: MySymbols.stockJournal)
                        .labelStyle(.titleAndIcon)
                }
            )
            //            //                Button(action: {
            //            //                    print("Stock Journal summary is not available yet")
            //            //                }, label: {
            //            //                    Text("Stock journal summary")
            //            //                })
            //            Button(action: {
            //                selectedStockElement = stockElement
            //                activeSheet = .editProduct
            //            }, label: {
            //                Label("Edit product", systemImage: MySymbols.edit)
            //            })
        }
    }
}

#Preview(traits: .previewData) {
    Menu("Preview") {
        StockTableMenuEntriesView(stockElement: StockElement(product: MDProduct()), quantityUnit: MDQuantityUnit())
    }
}
