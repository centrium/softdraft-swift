//
//  LibraryRailView.swift
//  SoftDraft
//
//  Created by Matt Adams on 31/01/2026.
//

import SwiftUI

struct LibraryRailView: View {

    let libraryURL: URL

    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var libraryManager: LibraryManager

    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ─────────────────────────────
            // Collections section
            // ─────────────────────────────

            Text("COLLECTIONS")
                .font(.caption)
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.top, 18)
                .padding(.bottom, 10)
                .padding(.horizontal, 14)

            CollectionsSidebar(
                libraryURL: libraryURL
            )
            .padding(.horizontal, 6)
            .padding(.bottom, 18)

            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, 14)

            // ─────────────────────────────
            // Notes section
            // ─────────────────────────────

            Text("Notes")
                .font(.caption)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            NotesListView(
                libraryURL: libraryURL,
                collection: selectedCollection
            )
            .padding(.horizontal, 6)
            .padding(.bottom, 16)

            // Prevents the rail from feeling pinned
            Spacer(minLength: 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
