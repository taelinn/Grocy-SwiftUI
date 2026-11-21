//
//  MDBatteriesView.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 17.11.20.
//

import SwiftUI

struct MDBatteriesView: View {
    @Environment(GrocyViewModel.self) private var grocyVM
    
    var body: some View {
        ContentUnavailableView(
            "Batteries",
            systemImage: MySymbols.batteries,
            description: Text("Battery tracking is not yet available.")
        )
    }
}

struct MDBatteriesView_Previews: PreviewProvider {
    static var previews: some View {
        MDBatteriesView()
    }
}
