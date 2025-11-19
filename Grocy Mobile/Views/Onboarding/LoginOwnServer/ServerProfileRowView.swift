//
//  ServerProfileRowView.swift
//  Grocy Mobile
//
//  Created by Georg Meißner on 17.11.25.
//

import SwiftUI

struct ServerProfileRowView: View {
    let profile: ServerProfile
    
    var body: some View {
        HStack {
            Text(profile.grocyServerURL)
                .font(.headline)
            if profile.useHassIngress {
                Spacer()
                Image(systemName: "house")
            }
            Spacer()
            Image(systemName: profile.isActive ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(profile.isActive ? .green : .primary)
        }
    }
}
