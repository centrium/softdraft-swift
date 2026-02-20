//
//  LibraryRailView.swift
//  SoftDraft
//
//  Created by Matt Adams on 31/01/2026.
//

import SwiftUI
import Combine

struct LibraryRailView: View {

    let libraryURL: URL

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var uiState: UIState
    @EnvironmentObject private var commandRegistry: CommandRegistry
    @State private var tagSelection: String? = nil
    @FocusState private var tagListFocused: Bool
    
    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private var activeLibraryName: String? {
        guard let name = libraryManager.activeLibraryURL?.lastPathComponent else {
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private let sidebarSlotHeight: CGFloat = 280

    private func requestTagListFocus() {
        tagListFocused = false
        DispatchQueue.main.async {
            tagListFocused = true
        }
    }

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
        commandRegistry.run(
            "tag.select",
            arguments: CommandArguments(tagID: target)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let activeLibraryName {
                Text(activeLibraryName)
                    .font(AppTypography.bodyEmphasis)
                    .foregroundStyle(Color.primary.opacity(0.90))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
            }

            VStack(alignment: .leading, spacing: 0) {

                if uiState.sidebarMode == .collections {
                    CollectionsSidebar(libraryURL: libraryURL)
                        .padding(.horizontal, 8)
                        .padding(.top, activeLibraryName == nil ? 8 : 0)

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
                                    .padding(.vertical, 4)

                                Text("#\(item.id)")
                                    .font(AppTypography.secondaryBody)
                                    .foregroundStyle(
                                        Color.primary.opacity(
                                            isSelected ? 0.90 : 0.84
                                        )
                                    )

                                Spacer()

                                Text("\(item.count)")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(Color.secondary.opacity(0.72))
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        isSelected
                                        ? AppTones.selectionFill(for: colorScheme)
                                        : .clear
                                    )
                            )
                            .listRowInsets(
                                EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
                            )
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                tagListFocused = true
                                guard tagSelection != item.id else { return }
                                tagSelection = item.id
                                commandRegistry.run(
                                    "tag.select",
                                    arguments: CommandArguments(tagID: item.id)
                                )
                            }
                            .contextMenu {
                                Button("Show Tagged Notes") {
                                    commandRegistry.run(
                                        "tag.select",
                                        arguments: CommandArguments(tagID: item.id)
                                    )
                                }
                                .disabled(
                                    !commandRegistry.canExecute(
                                        "tag.select",
                                        arguments: CommandArguments(tagID: item.id)
                                    )
                                )

                                Button("Remove Tag from Selected Note") {
                                    commandRegistry.run(
                                        "tag.removeFromNote",
                                        arguments: CommandArguments(
                                            noteID: selection.selectedNoteID,
                                            tagID: item.id
                                        )
                                    )
                                }
                                .disabled(
                                    !commandRegistry.canExecute(
                                        "tag.removeFromNote",
                                        arguments: CommandArguments(
                                            noteID: selection.selectedNoteID,
                                            tagID: item.id
                                        )
                                    )
                                )
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .focusable()
                    .focusEffectDisabled()
                    .scrollContentBackground(.hidden)
                    .padding(.top, activeLibraryName == nil ? 8 : 0)
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
                    .onReceive(uiState.$focusRequestToken.dropFirst()) { _ in
                        guard uiState.requestedFocusRegion == .sidebar else {
                            tagListFocused = false
                            return
                        }
                        guard uiState.sidebarMode == .tags else {
                            tagListFocused = false
                            return
                        }
                        requestTagListFocus()
                    }
                    .onChange(of: tagListFocused) { _, isFocused in
                        if isFocused {
                            uiState.activeFocusRegion = .sidebar
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: sidebarSlotHeight)
            .padding(.bottom, 12)
            
            if let tag = libraryManager.visibleTag {
                HStack(spacing: 8) {
                    Text("#\(tag)")
                        .font(AppTypography.secondaryBody)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        commandRegistry.run("tag.clearSelection")
                    } label: {
                        Text("Clear")
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .disabled(!commandRegistry.canExecute("tag.clearSelection"))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            

            NotesListView(
                libraryURL: libraryURL,
                collection: selectedCollection
            )
            .padding(.top, 8)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Spacer(minLength: 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppTones.sidebarBackground(for: colorScheme))
    }
}
