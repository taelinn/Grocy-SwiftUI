//
//  DeepLinkHandler.swift
//  Grocy Mobile
//
//  Created by Georg Meissner on 06.12.25.
//

import Foundation
import SwiftUI

enum GrocyDeepLink: Equatable {
    case stock(filter: ProductStatus)

    init?(url: URL) {
        guard url.scheme == "grocy" else { return nil }
        guard let host = url.host else { return nil }

        let pathComponents = url.pathComponents

        switch (host, pathComponents.count > 1 ? pathComponents[1] : nil) {
        case ("stock", "filter"):
            if pathComponents.count > 2 {
                let filterCaseName = pathComponents[2]
                if let status = ProductStatus.fromCaseName(filterCaseName) {
                    self = .stock(filter: status)
                    return
                }
            }
            return nil

        default:
            return nil
        }
    }

    func apply(to viewModel: @escaping (ProductStatus) -> Void) {
        switch self {
        case .stock(let filter):
            viewModel(filter)
        }
    }
}
