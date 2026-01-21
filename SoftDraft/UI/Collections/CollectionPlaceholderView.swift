//
//  CollectionPlaceholderView.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct CollectionPlaceholderView: View {

    let collection: String

    var body: some View {
        VStack(spacing: 12) {
            Text(collection)
                .font(.largeTitle)

            Text("Notes will appear here.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
