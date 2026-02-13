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
    @State private var hoveredTagID: String?
    @State private var tagSelection: String? = nil
    @FocusState private var tagsFocused: Bool
    
    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private let sidebarSlotHeight: CGFloat = 280

    private func moveTagSelection(
        _ direction: MoveCommandDirection,
        using proxy: ScrollViewProxy
    ) {
        guard uiState.sidebarMode == .tags else { return }

        let tagIDs = libraryManager.allTagsSorted.map(\.id)
        guard !tagIDs.isEmpty else { return }

        let nextID: String
        switch direction {
        case .down:
            if let current = libraryManager.visibleTag,
               let index = tagIDs.firstIndex(of: current) {
                nextID = tagIDs[min(index + 1, tagIDs.count - 1)]
            } else {
                nextID = tagIDs[0]
            }
        case .up:
            if let current = libraryManager.visibleTag,
               let index = tagIDs.firstIndex(of: current) {
                nextID = tagIDs[max(index - 1, 0)]
            } else {
                nextID = tagIDs[tagIDs.count - 1]
            }
        default:
            return
        }

        guard libraryManager.visibleTag != nextID else { return }
        libraryManager.selectTag(nextID)

        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(nextID, anchor: .center)
        }
    }

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

                    Text("TAGS")
                        .font(.caption)
                        .tracking(0.8)
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .padding(.horizontal, 14)

                    List(selection: $tagSelection) {
                        ForEach(libraryManager.allTagsSorted, id: \.id) { item in

                            let isSelected = tagSelection == item.id

                            HStack {
                                Text("#\(item.id)")
                                    .foregroundStyle(
                                        isSelected
                                        ? Color.primary
                                        : Color.primary.opacity(0.85)
                                    )

                                Spacer()

                                Text("\(item.count)")
                                    .foregroundStyle(
                                        isSelected
                                        ? Color.primary.opacity(0.75)
                                        : Color.secondary
                                    )
                            }
                            .font(.system(size: 13, weight: .regular))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 6)
                            .tag(item.id)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .onChange(of: tagSelection) { _, newValue in
                        guard let newValue else { return }
                        if libraryManager.visibleTag != newValue {
                            libraryManager.selectTag(newValue)
                        }
                    }
                    .onAppear {
                        tagSelection = libraryManager.visibleTag
                    }
                    .onChange(of: libraryManager.visibleTag) { _, newValue in
                        tagSelection = newValue
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: sidebarSlotHeight)
            .padding(.bottom, 16)

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
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("#\(tag)")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button {
                        libraryManager.clearTagSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
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
