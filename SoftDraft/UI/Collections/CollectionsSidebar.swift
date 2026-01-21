//
//  CollectionsSidebar.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct CollectionsSidebar: View {

    let libraryURL: URL
    @ObservedObject var selection: CollectionSelection

    @State private var collections: [String] = []

    var body: some View {
        List(selection: $selection.activeCollection) {
            ForEach(collections, id: \.self) { name in
                Text(name)
                    .tag(name)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Collections")
        .task(id: libraryURL.path) {
            await loadCollections()
        }
    }

    @MainActor
    private func loadCollections() async {
        do {
            let loaded = try CollectionStore.list(libraryURL: libraryURL)
            collections = loaded

            // ✅ ONLY reconcile on library load
            if !loaded.contains(selection.activeCollection) {
                selection.activeCollection = loaded.first ?? "Inbox"
            }
        } catch {
            collections = []
        }
    }
}
