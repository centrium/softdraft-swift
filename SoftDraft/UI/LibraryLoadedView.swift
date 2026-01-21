//
//  LibraryLoadedView.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//
import SwiftUI

struct LibraryLoadedView: View {

    let libraryURL: URL

    @StateObject private var selection = CollectionSelection()

    var body: some View {
        NavigationSplitView {
            CollectionsSidebar(
                libraryURL: libraryURL,
                selection: selection
            )
            .navigationSplitViewColumnWidth(
                    min: 220,
                    ideal: 260,
                    max: 320
                )
        } detail: {
            NotesListView(
                    libraryURL: libraryURL,
                    collection: selection.activeCollection
                )
        }
    }
}
