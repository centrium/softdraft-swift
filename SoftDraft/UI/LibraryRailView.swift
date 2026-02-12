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
    
    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private let sidebarSlotHeight: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

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

                    ForEach(libraryManager.allTagsSorted) { item in
                    Button {
                    libraryManager.selectTag(item.id)
                    } label: {
                    HStack {
                    Text("#\(item.id)")
                    Spacer()
                    Text("\(item.count)")
                    .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    }
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
            
            if let tag = libraryManager.visibleTag {
                Text("#(tag)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            

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

