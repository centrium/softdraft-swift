//
//  LibraryRailView.swift
//  SoftDraft
//
//  Created by Matt Adams on 31/01/2026.
//

import SwiftUI

struct LibraryRailView: View {

    let libraryURL: URL

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var uiState: UIState
    @State private var tagSelection: String? = nil
    @FocusState private var tagListFocused: Bool
    
    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private let sidebarSlotHeight: CGFloat = 280

    private func handleTagMoveCommand(_ direction: MoveCommandDirection) {
        let ids = libraryManager.allTagsSorted.map(\.id)
        guard !ids.isEmpty else { return }

        let currentIndex = tagSelection.flatMap { ids.firstIndex(of: $0) }
        let nextIndex: Int

        switch direction {
        case .down:
            if let currentIndex {
                nextIndex = min(currentIndex + 1, ids.count - 1)
            } else {
                nextIndex = 0
            }
        case .up:
            if let currentIndex {
                nextIndex = max(currentIndex - 1, 0)
            } else {
                nextIndex = ids.count - 1
            }
        default:
            return
        }

        let target = ids[nextIndex]
        guard target != tagSelection else { return }
        tagSelection = target
        DispatchQueue.main.async {
            libraryManager.selectTag(target)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            VStack(alignment: .leading, spacing: 0) {

                if uiState.sidebarMode == .collections {
                    CollectionsSidebar(libraryURL: libraryURL)
                        .padding(.horizontal, 6)
                        .padding(.top, 8)

                } else {
                    List {
                        ForEach(libraryManager.allTagsSorted, id: \.id) { item in

                            let isSelected = tagSelection == item.id

                            HStack {
                                Rectangle()
                                    .fill(
                                        SidebarAccentPalette.tags.opacity(
                                            isSelected
                                            ? SidebarAccentPalette.selectedStripOpacity
                                            : SidebarAccentPalette.stripOpacity
                                        )
                                    )
                                    .frame(width: SidebarAccentPalette.stripWidth)
                                    .padding(.vertical, 2)

                                Text("#\(item.id)")
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(Color.primary.opacity(0.84))

                                Spacer()

                                Text("\(item.count)")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(Color.secondary.opacity(0.75))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        isSelected
                                        ? Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05)
                                        : .clear
                                    )
                            )
                            .listRowInsets(
                                EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
                            )
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                tagListFocused = true
                                guard tagSelection != item.id else { return }
                                tagSelection = item.id
                                libraryManager.selectTag(item.id)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .focusable()
                    .focusEffectDisabled()
                    .scrollContentBackground(.hidden)
                    .padding(.top, 8)
                    .focused($tagListFocused)
                    .onMoveCommand { direction in
                        handleTagMoveCommand(direction)
                    }
                    .onKeyPress(phases: .down) { keyPress in
                        if keyPress.key == .downArrow {
                            handleTagMoveCommand(.down)
                            return .handled
                        }
                        if keyPress.key == .upArrow {
                            handleTagMoveCommand(.up)
                            return .handled
                        }
                        return .ignored
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
            .padding(.bottom, 12)
            
            if let tag = libraryManager.visibleTag {
                HStack(spacing: 8) {
                    Text("#\(tag)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        libraryManager.clearTagSelection()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            

            NotesListView(
                libraryURL: libraryURL,
                collection: selectedCollection
            )
            .padding(.top, 6)
            .padding(.horizontal, 6)
            .padding(.bottom, 8)

            Spacer(minLength: 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
