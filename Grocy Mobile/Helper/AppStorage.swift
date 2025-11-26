//
//  AppStorage.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 24.11.25.
//

import Foundation

extension UUID: @retroactive RawRepresentable {
    public var rawValue: String {
        self.uuidString
    }
    
    public typealias RawValue = String
    
    public init?(rawValue: RawValue) {
        self.init(uuidString: rawValue)
    }
}
