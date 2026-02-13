//
//  NotesListView.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct NotesListView: View {

    let libraryURL: URL
    let collection: String

    private enum FocusField {
        case search
        case results
    }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var selection: SelectionModel

    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry
    @EnvironmentObject private var searchIndex: SearchIndex
    @EnvironmentObject private var uiState: UIState

    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var searchSelection: String? = nil
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var hoveredSearchResult: String? = nil
    @FocusState private var focusedField: FocusField?
    
    private var collections: [String] {
        libraryManager.allCollections()
    }

    private var sortedVisibleNotes: [NoteSummary] {
        libraryManager.visibleNotes.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned
            }
            if lhs.modifiedAt != rhs.modifiedAt {
                return lhs.modifiedAt > rhs.modifiedAt
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private var pinnedVisibleNotes: [NoteSummary] {
        sortedVisibleNotes.filter(\.pinned)
    }

    private var unpinnedVisibleNotes: [NoteSummary] {
        sortedVisibleNotes.filter { !$0.pinned }
    }

    private var keyboardNavigableNoteIDs: [String] {
        sortedVisibleNotes.map(\.id)
    }

    private var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var modeAccentColor: Color {
        uiState.sidebarMode.sidebarAccentColor
    }

    private var selectionFill: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05)
    }

    private var isAwaitingTagSelection: Bool {
        uiState.sidebarMode == .tags && libraryManager.visibleTag == nil
    }

    private var contextLabel: String {
        if uiState.sidebarMode == .tags {
            return libraryManager.visibleTag.map { "#\($0)" } ?? "Tags"
        }
        return collection
    }

    var body: some View {
        ZStack {

            VStack(spacing: 0) {
                searchField

                List {
                    if !isSearchActive {
                        listTopSpacing
                    }

                    if isSearchActive {

                        // ───────── Search results ─────────
                        if isSearching && searchResults.isEmpty {
                            SearchStatusRow(label: "Searching...")
                                .listRowSeparator(.hidden)
                                .listRowInsets(
                                    EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
                                )
                                .transition(.opacity)
                        } else if searchResults.isEmpty {
                            SearchEmptyState(
                                query: searchQuery,
                                contextLabel: contextLabel
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(
                                EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
                            )
                            .transition(.opacity)
                        } else {
                            ForEach(displayedSearchResults) { result in
                                Button {
                                    openSearchResult(result.id)
                                } label: {
                                    SearchResultRow(
                                        note: result.note,
                                        isSelected: searchSelection == result.id,
                                        isHovered: result.isHovered,
                                        accentColor: modeAccentColor,
                                        accentOpacity: searchSelection == result.id
                                            ? SidebarAccentPalette.selectedStripOpacity
                                            : SidebarAccentPalette.stripOpacity,
                                        matchType: result.hint?.kindLabel,
                                        matchContext: result.hint?.context
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(minHeight: 36)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(
                                            searchSelection == result.id
                                            ? selectionFill
                                            : .clear
                                        )
                                )
                                .listRowInsets(
                                    EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
                                )
                                .listRowSeparator(.hidden)
                                .onTapGesture {
                                    focusedField = .results
                                    guard searchSelection != result.id else { return }
                                    searchSelection = result.id
                                }
                                .onHover { hovering in
                                    updateHoverState(for: result.id, hovering: hovering)
                                }
                            }
                        }

                    } else if isAwaitingTagSelection {
                        TagSelectionPlaceholder()
                            .listRowSeparator(.hidden)
                            .listRowInsets(
                                EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                            )
                    } else if libraryManager.visibleNotes.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                commandRegistry.run("note.create")
                            } label: {
                                Text("New note")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(pinnedVisibleNotes, id: \.id) { note in
                            NoteRow(
                                note: note,
                                isSelected: selection.selectedNoteID == note.id,
                                showsPinnedIndicator: note.pinned,
                                accentColor: modeAccentColor,
                                accentOpacity: noteAccentOpacity(
                                    isSelected: selection.selectedNoteID == note.id,
                                    isPinned: note.pinned
                                )
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 36)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        selection.selectedNoteID == note.id
                                        ? selectionFill
                                        : .clear
                                    )
                            )
                            .listRowInsets(
                                EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
                            )
                            .onTapGesture {
                                focusedField = .results
                                guard selection.selectedNoteID != note.id else { return }
                                selection.selectedNoteID = note.id
                            }
                        }

                        if !pinnedVisibleNotes.isEmpty && !unpinnedVisibleNotes.isEmpty {
                            Color.clear
                                .frame(height: 6)
                                .listRowInsets(
                                    EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                                )
                                .listRowSeparator(.hidden)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }

                        ForEach(unpinnedVisibleNotes, id: \.id) { note in
                            NoteRow(
                                note: note,
                                isSelected: selection.selectedNoteID == note.id,
                                showsPinnedIndicator: note.pinned,
                                accentColor: modeAccentColor,
                                accentOpacity: noteAccentOpacity(
                                    isSelected: selection.selectedNoteID == note.id,
                                    isPinned: note.pinned
                                )
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 36)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        selection.selectedNoteID == note.id
                                        ? selectionFill
                                        : .clear
                                    )
                            )
                            .listRowInsets(
                                EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
                            )
                            .onTapGesture {
                                focusedField = .results
                                guard selection.selectedNoteID != note.id else { return }
                                selection.selectedNoteID = note.id
                            }
                        }
                    }
                }
                .focused($focusedField, equals: .results)
                .listStyle(.sidebar)
                .focusable()
                .focusEffectDisabled()
                .navigationTitle(contextLabel)
                .onExitCommand {
                    if isSearchActive {
                        clearSearch()
                    }
                }
                .onKeyPress(.return) {
                    guard focusedField == .results, isSearchActive else {
                        return .ignored
                    }

                    if let target = searchSelection ?? displayedSearchResults.first?.id {
                        openSearchResult(target)
                        return .handled
                    }

                    return .ignored
                }
                .onMoveCommand { direction in
                    if isSearchActive {
                        handleSearchMoveCommand(direction)
                    } else {
                        handleNoteMoveCommand(direction)
                    }
                }
                .onKeyPress(phases: .down) { keyPress in
                    if keyPress.key == .downArrow {
                        if isSearchActive {
                            handleSearchMoveCommand(.down)
                        } else {
                            handleNoteMoveCommand(.down)
                        }
                        return .handled
                    }
                    if keyPress.key == .upArrow {
                        if isSearchActive {
                            handleSearchMoveCommand(.up)
                        } else {
                            handleNoteMoveCommand(.up)
                        }
                        return .handled
                    }
                    return .ignored
                }
                .onReceive(searchIndex.$entries) { _ in
                    guard isSearchActive else { return }
                    scheduleSearch(for: searchQuery)
                }
                .onReceive(libraryManager.$visibleNotes) { _ in
                    guard isSearchActive else { return }
                    scheduleSearch(for: searchQuery)
                }
                .animation(.easeOut(duration: 0.12), value: searchResults)
            }
            
            
            

            // ─────────────────────────────
            // Move Note Picker (overlay)
            // ─────────────────────────────
            if let pending = selection.pendingMove {
                MoveNotePicker(
                    selection: selection,
                    collections: collections,
                    onSelect: { destination in
                        selection.pendingMove = nil

                        selection.pendingMove = PendingMove(
                            noteID: pending.noteID,
                            destinationCollection: destination
                        )
                        commandRegistry.run("note.move.confirm")
                    },
                    onCancel: {
                        commandRegistry.run("command.cancel")
                    },
                )
                .background(
                    Color.black.opacity(0.05)
                        .ignoresSafeArea()
                )
            }
        }
    }

    private func scheduleSearch(for query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isSearching = false
            searchResults = []
            searchSelection = nil
            hoveredSearchResult = nil
            return
        }

        isSearching = true
        let scopedNoteIDs = Set(libraryManager.visibleNotes.map(\.id))

        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            let results = searchIndex.search(
                trimmed,
                scopedNoteIDs: scopedNoteIDs
            )
            isSearching = false
            updateSearchResults(results)
        }
    }

    private func updateSearchResults(_ results: [SearchResult]) {
        searchResults = results
        hoveredSearchResult = nil

        if let currentSelection = searchSelection,
           displayedSearchResults.contains(where: { $0.id == currentSelection }) {
            return
        }

        searchSelection = displayedSearchResults.first?.id
    }

    private func clearSearch() {
        searchTask?.cancel()
        searchQuery = ""
        searchResults = []
        searchSelection = nil
        hoveredSearchResult = nil
        isSearching = false
    }

    private func openSearchResult(_ id: String) {
        selection.selectedNoteID = id
        clearSearch()
    }

    private func handleSearchMoveCommand(_ direction: MoveCommandDirection) {
        guard isSearchActive else { return }
        guard !displayedSearchResults.isEmpty else { return }

        let ids = displayedSearchResults.map(\.id)
        let currentIndex = ids.firstIndex(of: searchSelection ?? "")

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

        searchSelection = ids[nextIndex]
    }

    private func handleNoteMoveCommand(_ direction: MoveCommandDirection) {
        guard !isSearchActive else { return }
        guard !isAwaitingTagSelection else { return }

        let ids = keyboardNavigableNoteIDs
        guard !ids.isEmpty else { return }

        let currentIndex = selection.selectedNoteID.flatMap { ids.firstIndex(of: $0) }
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
        guard target != selection.selectedNoteID else { return }
        DispatchQueue.main.async {
            selection.selectedNoteID = target
        }
    }

    private func updateHoverState(for id: String, hovering: Bool) {
        if hovering {
            hoveredSearchResult = id
        } else if hoveredSearchResult == id {
            hoveredSearchResult = nil
        }
    }

    private var listTopSpacing: some View {
        Color.clear
            .frame(height: 6)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.65))

            TextField("Search notes", text: $searchQuery)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .search)
                .onChange(of: searchQuery) { _, query in
                    scheduleSearch(for: query)
                }
                .onSubmit {
                    if let target = searchSelection ?? displayedSearchResults.first?.id {
                        openSearchResult(target)
                    }
                }
                .onMoveCommand { direction in
                    handleSearchMoveCommand(direction)
                }

            if !searchQuery.isEmpty {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 13, weight: .regular))
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .padding(.bottom, 6)
        .onExitCommand {
            if isSearchActive {
                clearSearch()
            }
        }
    }

    private var displayedSearchResults: [SearchDisplayResult] {
        let notesByID = Dictionary(
            uniqueKeysWithValues: libraryManager.visibleNotes.map { ($0.id, $0) }
        )
        let entriesByID = Dictionary(
            uniqueKeysWithValues: searchIndex.entries.map { ($0.id, $0) }
        )
        let query = normalisedSearchQuery(searchQuery)

        return searchResults.compactMap { result in
            guard let note = notesByID[result.id] else { return nil }

            return SearchDisplayResult(
                id: result.id,
                note: note,
                score: result.score,
                hint: SearchHint(
                    matchHint: result.matchHint,
                    note: note,
                    entry: entriesByID[result.id],
                    query: query
                ),
                isHovered: hoveredSearchResult == result.id
            )
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            let leftRank = lhs.hint?.rank ?? 3
            let rightRank = rhs.hint?.rank ?? 3
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.note.modifiedAt != rhs.note.modifiedAt {
                return lhs.note.modifiedAt > rhs.note.modifiedAt
            }
            return lhs.note.title.localizedCaseInsensitiveCompare(rhs.note.title) == .orderedAscending
        }
    }

    private func normalisedSearchQuery(_ rawQuery: String) -> String {
        var query = SearchNormaliser.normalise(rawQuery)
        while query.first == "#" {
            query.removeFirst()
        }
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func noteAccentOpacity(isSelected: Bool, isPinned: Bool) -> Double {
        if isSelected {
            return SidebarAccentPalette.selectedStripOpacity
        }
        if isPinned {
            return SidebarAccentPalette.pinnedStripOpacity
        }
        return SidebarAccentPalette.stripOpacity
    }
}

private struct SearchHint: Equatable {
    let rank: Int
    let kindLabel: String
    let context: String?

    init?(
        matchHint: String?,
        note: NoteSummary,
        entry: SearchIndexEntry?,
        query: String
    ) {
        guard let hint = matchHint else { return nil }
        if hint == "Tag" {
            rank = 0
            kindLabel = "tag"
            if let tag = entry?.tags.first(where: { $0.contains(query) }), !tag.isEmpty {
                context = "#\(tag)"
            } else if !query.isEmpty {
                context = "#\(query)"
            } else {
                context = nil
            }
        } else if hint == "Title" {
            rank = 1
            kindLabel = "title"
            context = Self.snippet(in: note.title, query: query)
        } else if hint == "Body" {
            rank = 3
            kindLabel = "body"
            context = Self.snippet(in: entry?.bodyText ?? "", query: query)
        } else {
            rank = 2
            kindLabel = "heading"
            context = hint
        }
    }

    private static func snippet(in source: String, query: String) -> String? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !query.isEmpty else { return String(trimmed.prefix(60)) }

        guard let range = trimmed.range(of: query, options: .caseInsensitive) else {
            return String(trimmed.prefix(60))
        }

        let index = trimmed.distance(from: trimmed.startIndex, to: range.lowerBound)
        let startOffset = max(0, index - 18)
        let endOffset = min(trimmed.count, index + query.count + 26)

        let start = trimmed.index(trimmed.startIndex, offsetBy: startOffset)
        let end = trimmed.index(trimmed.startIndex, offsetBy: endOffset)
        let slice = String(trimmed[start..<end]).trimmingCharacters(in: .whitespaces)
        if slice.isEmpty { return nil }

        let leading = startOffset > 0 ? "..." : ""
        let trailing = endOffset < trimmed.count ? "..." : ""
        return "\(leading)\(slice)\(trailing)"
    }
}

private struct SearchDisplayResult: Identifiable {
    let id: String
    let note: NoteSummary
    let score: Int
    let hint: SearchHint?
    let isHovered: Bool
}

private struct SearchResultRow: View {
    let note: NoteSummary
    let isSelected: Bool
    let isHovered: Bool
    let accentColor: Color
    let accentOpacity: Double
    let matchType: String?
    let matchContext: String?

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(accentColor.opacity(accentOpacity))
                .frame(width: SidebarAccentPalette.stripWidth)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(
                        isHovered
                        ? Color.primary.opacity(0.92)
                        : Color.primary.opacity(0.82)
                    )

                if let metadataLine, !metadataLine.isEmpty {
                    Text(metadataLine)
                        .font(.system(size: 11, weight: .regular))
                        .lineLimit(1)
                        .foregroundStyle(.secondary.opacity(0.72))
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
    }

    private var metadataLine: String? {
        let type = matchType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = matchContext?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let type, !type.isEmpty, let context, !context.isEmpty {
            return "\(type) · \(context)"
        }
        if let type, !type.isEmpty {
            return type
        }
        if let context, !context.isEmpty {
            return context
        }
        return nil
    }
}

private struct SearchStatusRow: View {
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private struct TagSelectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text("Choose a tag")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.78))
                Text("Select a tag from the sidebar to view its notes.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
    }
}

private struct SearchEmptyState: View {
    let query: String
    let contextLabel: String

    var body: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 6) {
            Text("No matches for \"\(trimmed)\"")
                .font(.body.weight(.medium))
            Text("Try a different word in \(contextLabel).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}
