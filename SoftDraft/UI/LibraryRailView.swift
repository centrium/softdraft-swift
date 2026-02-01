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
    @EnvironmentObject private var uiState: UIState
    @State private var searchText: String = ""

    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private let sidebarSlotHeight: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ───────── Search ─────────
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.06))
                )
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 10)

            // ───────── Mode Slot (Collections / Tags) ─────────
            VStack(alignment: .leading, spacing: 0) {

                if uiState.sidebarMode == .collections {

                    Text("COLLECTIONS")
                        .font(.caption)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)
                        .padding(.bottom, 10)
                        .padding(.horizontal, 14)

                    CollectionsSidebar(libraryURL: libraryURL)
                        .padding(.horizontal, 6)

                } else {

                    Text("TAGS")
                        .font(.caption)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)
                        .padding(.bottom, 10)
                        .padding(.horizontal, 14)

                    Text("Tags coming soon")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: sidebarSlotHeight)
            .padding(.bottom, 18)

            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, 14)

            // ───────── Notes (single source of truth) ─────────
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

            Spacer(minLength: 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

