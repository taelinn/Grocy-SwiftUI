//
//  Test_MDLocationModel.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 26.11.25.
//

import SwiftData
import XCTest

@testable import Grocy_Mobile

final class ModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        container = await PreviewContainer.shared
        context = ModelContext(container)
    }

    func testMDLocationModel() throws {
        let fetched = try context.fetch(FetchDescriptor<MDLocation>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testMDProductGroupModel() throws {
        let fetched = try context.fetch(FetchDescriptor<MDProductGroup>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testMDProductModel() throws {
        let fetched = try context.fetch(FetchDescriptor<MDProduct>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testMDQuantityUnitConversionModel() throws {
        let fetched = try context.fetch(FetchDescriptor<MDQuantityUnitConversion>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testMDQuantityUnitModel() throws {
        let fetched = try context.fetch(FetchDescriptor<MDQuantityUnit>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testShoppingListItemModel() throws {
        let fetched = try context.fetch(FetchDescriptor<ShoppingListItem>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testShoppingListDescriptionModel() throws {
        let fetched = try context.fetch(FetchDescriptor<ShoppingListDescription>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testMDStoreModel() throws {
        let fetched = try context.fetch(FetchDescriptor<MDStore>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testStockEntryModel() throws {
        let fetched = try context.fetch(FetchDescriptor<StockEntry>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
    
    func testStockJournalEntryModel() throws {
        let fetched = try context.fetch(FetchDescriptor<StockJournalEntry>())
        XCTAssertGreaterThan(fetched.count, 0)
    }
}
