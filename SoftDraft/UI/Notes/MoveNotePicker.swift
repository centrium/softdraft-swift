//
//  MoveNotePicker.swift
//  SoftDraft
//
//  Created by Matt Adams on 23/01/2026.
//

import SwiftUI

struct MoveNotePicker: View {

    @ObservedObject var selection: SelectionModel
    let collections: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack {
            Text("Move note to…")
            ForEach(collections, id: \.self) { collection in
                Button(collection) {
                    onSelect(collection)
                }
            }
        }
        .padding()
    }
}
