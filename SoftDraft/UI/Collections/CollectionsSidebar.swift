//
//  CollectionsSidebar.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct CollectionsSidebar: View {

    let libraryURL: URL
    @Binding var selectedCollection: String

    @State private var collections: [String] = []

    var body: some View {
        List(selection: $selectedCollection) {
            ForEach(collections, id: \.self) { name in
                Text(name)
                    .tag(name)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Collections")
        .task(id: libraryURL.path) {
            loadCollections()
        }
    }

    private func loadCollections() {
        do {
            let loaded = try CollectionStore.list(libraryURL: libraryURL)
            collections = loaded

            // ✅ Initial selection only
            if !loaded.contains(selectedCollection) {
                selectedCollection = loaded.first ?? "Inbox"
            }
        } catch {
            collections = []
        }
    }
}
