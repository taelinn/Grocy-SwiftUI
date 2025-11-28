//
//  MDProductFormView.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 19.11.20.
//

import SwiftData
import SwiftUI

enum MDProductFormPart: Hashable {
    case optional
    case location
    case dueDate
    case quantityUnit
    case amount
    case barcode
    case productPicture
}

enum ExternalBarcodeLookupState {
    case searching, success, notFound, error
}

struct MDProductFormView: View {
    @Environment(GrocyViewModel.self) private var grocyVM

    @Query(sort: \MDProduct.name, order: .forward) var mdProducts: MDProducts
    @Query(sort: \MDProductBarcode.id, order: .forward) var mdProductBarcodes: MDProductBarcodes
    @Query(filter: #Predicate<MDQuantityUnit> { $0.active }, sort: \MDQuantityUnit.id, order: .forward) var mdQuantityUnits: MDQuantityUnits
    @Query(filter: #Predicate<MDProductGroup> { $0.active }, sort: \MDProductGroup.id, order: .forward) var mdProductGroups: MDProductGroups
    @Query(filter: #Predicate<MDStore> { $0.active }, sort: \MDStore.name, order: .forward) var mdStores: MDStores
    @Query(filter: #Predicate<MDLocation> { $0.active }, sort: \MDLocation.name, order: .forward) var mdLocations: MDLocations

    @Environment(\.dismiss) var dismiss

    @State private var isProcessing: Bool = false
    @State private var isSuccessful: Bool? = nil
    @State private var errorMessage: String? = nil

    @Binding var createdProductID: Int?
    var createBarcode: Bool

    var existingProduct: MDProduct?
    @State var product: MDProduct

    @AppStorage("devMode") private var devMode: Bool = false

    @State private var queuedBarcode: String = ""
    @State private var foundExternalBarcode: ExternalBarcodeLookup?
    @State private var externalBarcodeState: ExternalBarcodeLookupState?
    @State private var barcodeLookupApplied: Bool = false

    @State private var isNameCorrect: Bool = true
    private func checkNameCorrect() -> Bool {
        let foundProduct = mdProducts.first(where: { $0.name == product.name })
        return existingProduct == nil ? !(product.name.isEmpty || foundProduct != nil) : !(product.name.isEmpty || (foundProduct != nil && foundProduct!.id != product.id))
    }

    @State private var isBarcodeCorrect: Bool = true
    private func checkBarcodeCorrect() -> Bool {
        let foundBarcode = mdProductBarcodes.first(where: { $0.barcode == queuedBarcode })
        return (queuedBarcode.isEmpty || (foundBarcode == nil))
    }

    init(existingProduct: MDProduct? = nil, userSettings: GrocyUserSettings? = nil, queuedBarcode: String? = nil, createBarcode: Bool = false, createdProductID: Binding<Int?> = .constant(nil)) {
        self.existingProduct = existingProduct
        self.queuedBarcode = queuedBarcode ?? ""
        self.createBarcode = createBarcode
        let initialProduct =
            existingProduct
            ?? MDProduct(
                productGroupID: userSettings?.productPresetsProductGroupID,
                locationID: userSettings?.productPresetsLocationID ?? -1,
                quIDPurchase: userSettings?.productPresetsQuID ?? -1,
                quIDStock: userSettings?.productPresetsQuID ?? -1,
                quIDConsume: userSettings?.productPresetsQuID ?? -1,
                quIDPrice: userSettings?.productPresetsQuID ?? -1,
                defaultDueDays: userSettings?.productPresetsDefaultDueDays ?? 0,
                treatOpenedAsOutOfStock: userSettings?.productPresetsTreatOpenedAsOutOfStock ?? false,
            )
        _product = State(initialValue: initialProduct)
        _isNameCorrect = State(initialValue: true)
        _createdProductID = createdProductID
    }

    private var currentQUPurchase: MDQuantityUnit? {
        return mdQuantityUnits.first(where: { $0.id == product.quIDPurchase })
    }
    private var currentQUStock: MDQuantityUnit? {
        return mdQuantityUnits.first(where: { $0.id == product.quIDStock })
    }

    private let dataToUpdate: [ObjectEntities] = [.products, .quantity_units, .locations, .shopping_locations, .product_barcodes]
    private let additionalDataToUpdate: [AdditionalEntities] = [.system_info]
    private func updateData() async {
        await grocyVM.requestData(objects: dataToUpdate, additionalObjects: additionalDataToUpdate)
    }

    private func finishForm() {
        self.dismiss()
    }

    private var isFormValid: Bool {
        !(product.name.isEmpty) && isNameCorrect && (product.locationID != -1) && (product.quIDStock != -1) && (product.quIDPurchase != -1) && (product.quIDConsume != -1) && (product.quIDPrice != -1) && isBarcodeCorrect
    }

    private func saveProduct() async {
        if product.id == -1 {
            product.id = grocyVM.findNextID(.products)
        }
        isProcessing = true
        isSuccessful = nil
        do {
            try product.modelContext?.save()
            if existingProduct == nil {
                _ = try await grocyVM.postMDObject(object: .products, content: product)
                await grocyVM.requestData(objects: [.products])
                createdProductID = product.id
                if createBarcode == true && !queuedBarcode.isEmpty {
                    let newBarcode = MDProductBarcode(
                        id: grocyVM.findNextID(.product_barcodes),
                        productID: product.id,
                        barcode: queuedBarcode
                    )
                    let _ = try await grocyVM.postMDObject(object: .product_barcodes, content: newBarcode)
                    GrocyLogger.info("Barcode add successful.")
                    await grocyVM.requestData(objects: [.product_barcodes])
                }
                GrocyLogger.info("Product \(product.name) successful.")
                isSuccessful = true
            } else {
                try await grocyVM.putMDObjectWithID(object: .products, id: product.id, content: product)
                GrocyLogger.info("Product \(product.name) successful.")
                await grocyVM.requestData(objects: [.products])
                isSuccessful = true
            }
        } catch {
            GrocyLogger.error("Product \(product.name) failed. \(error)")
            errorMessage = error.localizedDescription
            isSuccessful = false
        }
        isProcessing = false
    }

    var body: some View {
        List {
            MyTextField(textToEdit: $product.name, description: "Name", isCorrect: $isNameCorrect, leadingIcon: "tag", emptyMessage: "A name is required", errorMessage: "Name already exists")
                .onChange(of: product.name) {
                    isNameCorrect = checkNameCorrect()
                }

            if !queuedBarcode.isEmpty && existingProduct == nil {
                Section("Barcode") {
                    MyTextField(textToEdit: $queuedBarcode, description: "Barcode", isCorrect: $isBarcodeCorrect, leadingIcon: MySymbols.barcode, errorMessage: "The barcode is invalid or already in use.")
                        .onChange(of: queuedBarcode) {
                            isBarcodeCorrect = checkBarcodeCorrect()
                        }
                        .disabled(true)
                    if foundExternalBarcode == nil && (externalBarcodeState == nil || externalBarcodeState == .error) {
                        Button(
                            action: {
                                Task {
                                    barcodeLookupApplied = false
                                    externalBarcodeState = .searching
                                    do {
                                        foundExternalBarcode = try await grocyVM.externalBarcodeLookup(barcode: queuedBarcode)
                                        if foundExternalBarcode != nil {
                                            externalBarcodeState = .success
                                        } else {
                                            externalBarcodeState = .notFound
                                        }
                                    } catch {
                                        GrocyLogger.error("\(error)")
                                        externalBarcodeState = .error
                                    }
                                }
                            },
                            label: {
                                Label("External barcode lookup", systemImage: MySymbols.search)
                            }
                        )
                    }
                    if !barcodeLookupApplied {
                        switch externalBarcodeState {
                        case .searching:
                            ProgressView()
                                .progressViewStyle(.circular)
                        case .success:
                            if let foundExternalBarcode {
                                DisclosureGroup(
                                    content: {
                                        LabeledContent(
                                            content: {
                                                Text(mdLocations.first(where: { $0.id == foundExternalBarcode.locationID })?.name ?? String(foundExternalBarcode.locationID))
                                            },
                                            label: {
                                                Label("Default location", systemImage: MySymbols.location)
                                            }
                                        )
                                        .foregroundStyle(.primary)
                                        LabeledContent(
                                            content: {
                                                Text(mdQuantityUnits.first(where: { $0.id == foundExternalBarcode.quIDStock })?.name ?? String(foundExternalBarcode.quIDStock))
                                            },
                                            label: {
                                                Label("Quantity unit stock", systemImage: MySymbols.quantityUnit)
                                            }
                                        )
                                        .foregroundStyle(.primary)
                                        LabeledContent(
                                            content: {
                                                Text(mdQuantityUnits.first(where: { $0.id == foundExternalBarcode.quIDPurchase })?.name ?? String(foundExternalBarcode.quIDPurchase))
                                            },
                                            label: {
                                                Label("Default quantity unit purchase", systemImage: MySymbols.quantityUnit)
                                            }
                                        )
                                        .foregroundStyle(.primary)
                                        AsyncImage(url: URL(string: foundExternalBarcode.imageURL))
                                    },
                                    label: {
                                        Text(foundExternalBarcode.name)
                                    }
                                )
                                Button(
                                    action: {
                                        barcodeLookupApplied = true
                                        product.name = foundExternalBarcode.name
                                        product.locationID = foundExternalBarcode.locationID
                                        product.quIDPurchase = foundExternalBarcode.quIDPurchase
                                        product.quIDStock = foundExternalBarcode.quIDStock
                                        product.quIDPrice = foundExternalBarcode.quIDStock
                                        product.quIDConsume = foundExternalBarcode.quIDStock
                                    },
                                    label: {
                                        Label("Apply", systemImage: MySymbols.save)
                                    }
                                )
                            }
                        case .error:
                            Text("Error while executing the barcode lookup plugin").foregroundStyle(.red)
                        case .notFound:
                            Text("Nothing was found for the given barcode").foregroundStyle(.red)
                        default: EmptyView()
                        }
                    }
                }
            }

            Section {
                NavigationLink(
                    value: MDProductFormPart.optional,
                    label: {
                        MyLabelWithSubtitle(
                            title: "Optional properties",
                            subTitle: "\(Text("Status")), \(Text("Parent product")), \(Text("Description")), \(Text("Product group")), \(Text("Energy")), \(Text("Picture"))",
                            systemImage: MySymbols.description
                        )
                    }
                )
                NavigationLink(
                    value: MDProductFormPart.location,
                    label: {
                        MyLabelWithSubtitle(title: "Default location", subTitle: "\(Text("Location")), \(Text("Store"))", systemImage: MySymbols.location, isProblem: product.locationID == -1)
                    }
                )
                NavigationLink(
                    value: MDProductFormPart.dueDate,
                    label: {
                        MyLabelWithSubtitle(title: "Due date", subTitle: "\(Text("Type")), \(Text("Default due days"))", systemImage: MySymbols.date)
                    }
                )
                NavigationLink(
                    value: MDProductFormPart.quantityUnit,
                    label: {
                        MyLabelWithSubtitle(
                            title: "Quantity units",
                            subTitle: "\(Text("Stock")), \(Text("Purchase"))",
                            systemImage: MySymbols.quantityUnit,
                            isProblem: (product.quIDStock == -1 || product.quIDPurchase == -1 || product.quIDConsume == -1 || product.quIDPrice == -1)
                        )
                    }
                )
                NavigationLink(
                    value: MDProductFormPart.amount,
                    label: {
                        MyLabelWithSubtitle(title: "Amount", subTitle: "\(Text("Min. stock amount")), \(Text("Quick consume amount")), \(Text("Factor")), \(Text("Tare weight"))", systemImage: MySymbols.amount)
                    }
                )
                if queuedBarcode.isEmpty || createBarcode == false {
                    NavigationLink(
                        value: MDProductFormPart.barcode,
                        label: {
                            MyLabelWithSubtitle(title: "Barcodes", subTitle: existingProduct == nil ? "Product is not on server" : "", systemImage: MySymbols.barcode, hideSubtitle: existingProduct != nil)
                        }
                    )
                    .disabled(existingProduct == nil)
                } else {
                    MyLabelWithSubtitle(title: "\(Text("Barcode")): \(queuedBarcode)", systemImage: MySymbols.barcode)
                }
            }
        }
        .task {
            await updateData()
            self.isNameCorrect = checkNameCorrect()
        }
        .navigationTitle(existingProduct == nil ? "Create product" : "Edit product")
        .toolbar(content: {
            if existingProduct == nil {
                ToolbarItem(
                    placement: .cancellationAction,
                    content: {
                        Button(
                            role: .cancel,
                            action: {
                                finishForm()
                            }
                        )
                        .keyboardShortcut(.cancelAction)
                    }
                )
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(
                    role: .confirm,
                    action: {
                        Task {
                            await saveProduct()
                        }
                    }
                )
                .disabled(!isFormValid)
                .keyboardShortcut(.defaultAction)
            }
        })
        .navigationDestination(
            for: MDProductFormPart.self,
            destination: { formPart in
                switch formPart {
                case .optional:
                    optionalPropertiesView
                case .location:
                    locationPropertiesView
                case .dueDate:
                    dueDatePropertiesView
                case .quantityUnit:
                    quantityUnitPropertiesView
                case .amount:
                    amountPropertiesView
                case .barcode:
                    barcodePropertiesView
                case .productPicture:
                    MDProductPictureFormViewNew(existingProduct: existingProduct, pictureFileName: $product.pictureFileName)
                }
            }
        )
        .onChange(of: isSuccessful) {
            if isSuccessful == true {
                finishForm()
            }
        }
        .sensoryFeedback(.success, trigger: isSuccessful == true)
        .sensoryFeedback(.error, trigger: isSuccessful == false)
    }

    var optionalPropertiesView: some View {
        Form {
            // Active
            MyToggle(isOn: $product.active, description: "Active", descriptionInfo: nil, icon: "checkmark.circle")

            // Parent Product
            ProductField(productID: $product.parentProductID, description: "Parent product")

            // Product Description
            MyTextField(textToEdit: $product.mdProductDescription, description: "Description", isCorrect: Binding.constant(true), leadingIcon: MySymbols.description)

            // Product group
            Picker(
                selection: $product.productGroupID,
                label: HStack {
                    Image(systemName: MySymbols.productGroup)
                        .foregroundStyle(.primary)
                    Text("Product group")
                },
                content: {
                    Text("").tag(nil as Int?)
                    ForEach(mdProductGroups.filter({ $0.active }), id: \.id) { grocyProductGroup in
                        Text(grocyProductGroup.name).tag(grocyProductGroup.id as Int?)
                    }
                }
            )

            // Energy
            MyDoubleStepperOptional(amount: $product.calories, description: "\(Text("Energy")) (kcal)", descriptionInfo: "Per stock quantity unit", minAmount: 0, amountStep: 1, amountName: "kcal", systemImage: MySymbols.energy)

            // Don't show on stock overview
            MyToggle(
                isOn: $product.hideOnStockOverview,
                description: "Never show on stock overview",
                descriptionInfo: "The stock overview page lists all products which are currently in-stock or below their min. stock amount - enable this to hide this product there always",
                icon: MySymbols.stockOverview
            )

            // Disable own stock
            MyToggle(
                isOn: $product.noOwnStock,
                description: "Disable own stock",
                descriptionInfo: "When enabled, this product can't have own stock, means it will not be selectable on purchase (useful for parent products which are just used as a summary/total view of the child products)",
                icon: MySymbols.stockOverview
            )

            // Product should not be frozen
            MyToggle(
                isOn: $product.shouldNotBeFrozen,
                description: "Should not be frozen",
                descriptionInfo: "When enabled, on moving this product to a freezer location (so when freezing it), a warning will be shown",
                icon: MySymbols.freezing
            )

            // Product picture
            NavigationLink(
                value: MDProductFormPart.productPicture,
                label: {
                    MyLabelWithSubtitle(title: "Product picture", subTitle: (product.pictureFileName ?? "").isEmpty ? "No product picture" : "Product picture found", systemImage: MySymbols.picture)
                }
            )
            .disabled(existingProduct == nil)
        }
        .navigationTitle("Optional properties")
    }

    var locationPropertiesView: some View {
        Form {
            // Default Location - REQUIRED
            Picker(
                selection: $product.locationID,
                label: MyLabelWithSubtitle(title: "Default location", subTitle: "A location is required", systemImage: MySymbols.location, isSubtitleProblem: true, hideSubtitle: product.locationID != -1),
                content: {
                    Text("").tag(-1 as Int?)
                    ForEach(mdLocations.filter({ $0.active }), id: \.id) { grocyLocation in
                        Text(grocyLocation.name).tag(grocyLocation.id as Int?)
                    }
                }
            )
            // Default consume location
            HStack {
                Picker(
                    selection: $product.defaultConsumeLocationID,
                    label: MyLabelWithSubtitle(title: "Default consume location", systemImage: MySymbols.location, hideSubtitle: true),
                    content: {
                        Text("").tag(-1 as Int?)
                        ForEach(mdLocations.filter({ $0.active }), id: \.id) { grocyLocation in
                            Text(grocyLocation.name).tag(grocyLocation.id as Int?)
                        }
                    }
                )
                FieldDescription(description: "Stock entries at this location will be consumed first")
            }

            // Move on open
            if product.defaultConsumeLocationID != -1 {
                MyToggle(
                    isOn: $product.moveOnOpen,
                    description: "Move on open",
                    descriptionInfo: "When enabled, on marking this product as opened, the corresponding amount will be moved to the default consume location",
                    icon: MySymbols.transfer
                )
            }

            // Default Store
            Picker(
                selection: $product.storeID,
                label: MyLabelWithSubtitle(title: "Default store", systemImage: MySymbols.store, hideSubtitle: true),
                content: {
                    Text("").tag(-1 as Int?)
                    ForEach(mdStores.filter({ $0.active }), id: \.id) { grocyStore in
                        Text(grocyStore.name).tag(grocyStore.id as Int?)
                    }
                }
            )
        }
        .navigationTitle("Default location")
    }

    var dueDatePropertiesView: some View {
        Form {
            VStack(alignment: .leading) {
                Text("Due date type")
                    .font(.headline)
                // Due Type, default best before
                Picker(
                    "",
                    selection: $product.dueType,
                    content: {
                        Text("Best before date")
                            .tag(DueType.bestBefore.rawValue)
                        Text("Expiration date")
                            .tag(DueType.expires.rawValue)
                    }
                )
                .pickerStyle(.segmented)
            }

            // Default due days
            MyIntStepper(
                amount: $product.defaultDueDays,
                description: "Default due days",
                helpText: "For purchases this amount of days will be added to today for the due date suggestion (-1 means that this product will be never overdue)",
                minAmount: -1,
                amountName: product.defaultDueDays == 1 ? "Day" : "Days",
                systemImage: MySymbols.date
            )

            // Default due days afer opening
            MyIntStepper(
                amount: $product.defaultDueDaysAfterOpen,
                description: "Default due days after opened",
                helpText: "When this product was marked as opened, the due date will be replaced by today + this amount of days (a value of 0 disables this)",
                minAmount: 0,
                amountName: product.defaultDueDaysAfterOpen == 1 ? "Day" : "Days",
                systemImage: MySymbols.date
            )

            // Default due days after freezing
            MyIntStepper(
                amount: $product.defaultDueDaysAfterFreezing,
                description: "Default due days after freezing",
                helpText: "On moving this product to a freezer location (so when freezing it), the due date will be replaced by today + this amount of days",
                minAmount: -1,
                amountName: product.defaultDueDaysAfterFreezing == 1 ? "Day" : "Days",
                errorMessage: "This cannot be lower than \(Double(-1.0).formatted(.number.precision(.fractionLength(0...4)))) and needs to be a valid number with max. \(Int(0)) decimal places",
                systemImage: MySymbols.freezing
            )

            // Default due days after thawing
            MyIntStepper(
                amount: $product.defaultDueDaysAfterThawing,
                description: "Default due days after thawing",
                helpText: "On moving this product from a freezer location (so when thawing it), the due date will be replaced by today + this amount of days",
                minAmount: 0,
                amountName: product.defaultDueDaysAfterThawing == 1 ? "Day" : "Days",
                errorMessage: "This cannot be lower than \(Double(0.0).formatted(.number.precision(.fractionLength(0...4)))) and needs to be a valid number with max. \(Int(0)) decimal places",
                systemImage: MySymbols.thawing
            )
        }
        .navigationTitle("Due date")
    }

    var quantityUnitPropertiesView: some View {
        Form {
            // Default Quantity Unit Stock - REQUIRED
            HStack {
                Picker(
                    selection: $product.quIDStock,
                    label: MyLabelWithSubtitle(title: "Quantity unit stock", subTitle: "A quantity unit is required", systemImage: MySymbols.quantityUnit, isSubtitleProblem: true, hideSubtitle: product.quIDStock != -1),
                    content: {
                        Text("").tag(-1 as Int?)
                        ForEach(mdQuantityUnits.filter({ $0.active }), id: \.id) { grocyQuantityUnit in
                            Text(grocyQuantityUnit.name).tag(grocyQuantityUnit.id as Int?)
                        }
                    }
                )
                .onChange(of: product.quIDStock) {
                    if product.quIDPurchase == -1 {
                        product.quIDPurchase = product.quIDStock
                    }
                    if product.quIDConsume == -1 {
                        product.quIDConsume = product.quIDStock
                    }
                    if product.quIDPrice == -1 {
                        product.quIDPrice = product.quIDStock
                    }
                }

                FieldDescription(description: "Quantity unit stock cannot be changed after first purchase")
            }

            // Default Quantity Unit Purchase - REQUIRED
            HStack {
                Picker(
                    selection: $product.quIDPurchase,
                    label: MyLabelWithSubtitle(title: "Default quantity unit purchase", subTitle: "A quantity unit is required", systemImage: MySymbols.quantityUnit, isSubtitleProblem: true, hideSubtitle: product.quIDPurchase != -1),
                    content: {
                        Text("")
                            .tag(nil as Int?)
                        ForEach(mdQuantityUnits.filter({ $0.active }), id: \.id) { grocyQuantityUnit in
                            Text(grocyQuantityUnit.name)
                                .tag(grocyQuantityUnit.id as Int?)
                        }
                    }
                )
                FieldDescription(description: "This is the default quantity unit used when adding this product to the shopping list")
            }

            // Default Quantity Unit Consume - REQUIRED
            HStack {
                Picker(
                    selection: $product.quIDConsume,
                    label: MyLabelWithSubtitle(title: "Default quantity unit consume", subTitle: "A quantity unit is required", systemImage: MySymbols.quantityUnit, isSubtitleProblem: true, hideSubtitle: product.quIDConsume != -1),
                    content: {
                        Text("")
                            .tag(nil as Int?)
                        ForEach(mdQuantityUnits.filter({ $0.active }), id: \.id) { grocyQuantityUnit in
                            Text(grocyQuantityUnit.name)
                                .tag(grocyQuantityUnit.id as Int?)
                        }
                    }
                )
                FieldDescription(description: "This is the default quantity unit used when consuming this product")
            }

            // Default Quantity Unit Price - REQUIRED
            HStack {
                Picker(
                    selection: $product.quIDPrice,
                    label: MyLabelWithSubtitle(title: "Quantity unit for prices", subTitle: "A quantity unit is required", systemImage: MySymbols.quantityUnit, isSubtitleProblem: true, hideSubtitle: product.quIDPrice != -1),
                    content: {
                        Text("")
                            .tag(nil as Int?)
                        ForEach(mdQuantityUnits.filter({ $0.active }), id: \.id) { grocyQuantityUnit in
                            Text(grocyQuantityUnit.name)
                                .tag(grocyQuantityUnit.id as Int?)
                        }
                    }
                )
                FieldDescription(description: "When displaying prices for this product, they will be related to this quantity unit")
            }
        }
        .navigationTitle("Quantity units")
    }

    var amountPropertiesView: some View {
        Form {
            // Min Stock amount
            MyDoubleStepper(amount: $product.minStockAmount, description: "Minimum stock amount", minAmount: 0, amountStep: 1, amountName: currentQUStock?.name ?? "QU", systemImage: MySymbols.amount)

            // Accumulate sub products min stock amount
            MyToggle(
                isOn: $product.cumulateMinStockAmountOfSubProducts,
                description: "Accumulate sub products min. stock amount",
                descriptionInfo: "If enabled, the min. stock amount of sub products will be accumulated into this product, means the sub product will never be \"missing\", only this product",
                icon: MySymbols.accumulate
            )

            // Treat opened as out of stock
            MyToggle(
                isOn: $product.treatOpenedAsOutOfStock,
                description: "Treat opened as out of stock",
                descriptionInfo: "When enabled, opened items will be counted as missing for calculating if this product is below its minimum stock amount",
                icon: MySymbols.stockOverview
            )

            // Quick consume amount
            MyDoubleStepperOptional(
                amount: $product.quickConsumeAmount,
                description: "Quick consume amount",
                descriptionInfo: "This amount is used for the \"quick consume button\" on the stock overview page (related to quantity unit stock)",
                minAmount: 0.0001,
                amountStep: 1.0,
                amountName: nil,
                systemImage: MySymbols.consume
            )

            // Quick open amount
            MyDoubleStepperOptional(
                amount: $product.quickOpenAmount,
                description: "Quick open amount",
                descriptionInfo: "This amount is used for the \"quick open button\" on the stock overview page (related to quantity unit stock)",
                minAmount: 0.0001,
                amountStep: 1.0,
                amountName: nil,
                systemImage: MySymbols.open
            )

            // Tare weight
            Group {
                MyToggle(
                    isOn: $product.enableTareWeightHandling,
                    description: "Enable tare weight handling",
                    descriptionInfo:
                        "This is useful e.g. for flour in jars - on purchase/consume/inventory you always weigh the whole jar, the amount to be posted is then automatically calculated based on what is in stock and the tare weight defined below",
                    icon: MySymbols.tareWeight
                )

                if product.enableTareWeightHandling {
                    MyDoubleStepperOptional(amount: $product.tareWeight, description: "Tare weight", minAmount: 0, amountStep: 1, amountName: currentQUStock?.name ?? "QU", systemImage: MySymbols.tareWeight)
                }
            }

            // Check stock fulfillment for recipes
            MyToggle(
                isOn: $product.notCheckStockFulfillmentForRecipes,
                description: "Disable stock fulfillment checking for this ingredient",
                descriptionInfo: "This will be used as the default setting when adding this product as a recipe ingredient",
                icon: MySymbols.recipe
            )
        }
        .navigationTitle("Amounts")
    }

    var barcodePropertiesView: some View {
        Group {
            if existingProduct != nil {
                MDBarcodesView(product: product)
            }
        }
    }
}

#Preview {
    MDProductFormView()
}
