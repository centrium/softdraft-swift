//
//  NotesListView.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI
import Combine

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

    private var stateFilteredVisibleNotes: [NoteSummary] {
        NoteStateFiltering.filteredNotes(
            from: libraryManager.visibleNotes,
            stateFilter: uiState.noteStateFilter
        )
    }

    private var sortedVisibleNotes: [NoteSummary] {
        stateFilteredVisibleNotes.sorted { lhs, rhs in
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

    private var stateFilterLabel: String {
        uiState.noteStateFilter?.displayName ?? "All"
    }

    private var isStateFilterActive: Bool {
        uiState.noteStateFilter != nil
    }

    private var filteredEmptyMessage: String? {
        guard let state = uiState.noteStateFilter else { return nil }
        return "No \(state.displayName) notes"
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
                                    .frame(minHeight: 32)
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
                                    EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
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
                    } else if stateFilteredVisibleNotes.isEmpty {
                        HStack {
                            Spacer()
                            if let filteredEmptyMessage {
                                Text(filteredEmptyMessage)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button {
                                    commandRegistry.run("note.create")
                                } label: {
                                    Text("New note")
                                        .font(AppTypography.captionEmphasis)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
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
                            .frame(minHeight: 32)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        selection.selectedNoteID == note.id
                                        ? selectionFill
                                        : .clear
                                    )
                            )
                            .listRowInsets(
                                EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
                            )
                            .onTapGesture {
                                focusedField = .results
                                guard selection.selectedNoteID != note.id else { return }
                                commandRegistry.run(
                                    "note.select",
                                    arguments: CommandArguments(noteID: note.id)
                                )
                            }
                            .contextMenu {
                                noteContextMenu(for: note)
                            }
                        }

                        if !pinnedVisibleNotes.isEmpty && !unpinnedVisibleNotes.isEmpty {
                            Color.clear
                                .frame(height: 8)
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
                            .frame(minHeight: 32)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        selection.selectedNoteID == note.id
                                        ? selectionFill
                                        : .clear
                                    )
                            )
                            .listRowInsets(
                                EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
                            )
                            .onTapGesture {
                                focusedField = .results
                                guard selection.selectedNoteID != note.id else { return }
                                commandRegistry.run(
                                    "note.select",
                                    arguments: CommandArguments(noteID: note.id)
                                )
                            }
                            .contextMenu {
                                noteContextMenu(for: note)
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
                .onReceive(uiState.$focusRequestToken.dropFirst()) { _ in
                    guard uiState.requestedFocusRegion == .notesList else {
                        focusedField = nil
                        return
                    }
                    focusedField = .results
                }
                .onChange(of: focusedField) { _, newValue in
                    if newValue != nil {
                        uiState.activeFocusRegion = .notesList
                    }
                }
                .animation(.easeOut(duration: 0.12), value: searchResults)
            }
        }
    }

    @ViewBuilder
    private func noteContextMenu(for note: NoteSummary) -> some View {
        Button("Move to…") {
            commandRegistry.run(
                "note.move",
                arguments: CommandArguments(noteID: note.id)
            )
        }
        .disabled(
            !commandRegistry.canExecute(
                "note.move",
                arguments: CommandArguments(noteID: note.id)
            )
        )

        Button(note.pinned ? "Unpin" : "Pin") {
            commandRegistry.run(
                "note.togglePin",
                arguments: CommandArguments(noteID: note.id)
            )
        }
        .disabled(
            !commandRegistry.canExecute(
                "note.togglePin",
                arguments: CommandArguments(noteID: note.id)
            )
        )

        Menu("State") {
            let currentState = note.state
            ForEach(NoteState.allCases, id: \.self) { state in
                Button {
                    commandRegistry.run(
                        "note.setState",
                        arguments: CommandArguments(
                            noteID: note.id,
                            noteState: state
                        )
                    )
                } label: {
                    if currentState == state {
                        Label(state.displayName, systemImage: "checkmark")
                    } else {
                        Text(state.displayName)
                    }
                }
                .disabled(
                    !commandRegistry.canExecute(
                        "note.setState",
                        arguments: CommandArguments(
                            noteID: note.id,
                            noteState: state
                        )
                    )
                )

                Button("Filter by This State") {
                    commandRegistry.run(
                        "note.stateFilter.set",
                        arguments: CommandArguments(noteState: state)
                    )
                }
                .disabled(
                    !commandRegistry.canExecute(
                        "note.stateFilter.set",
                        arguments: CommandArguments(noteState: state)
                    )
                )

                if state != NoteState.allCases.last {
                    Divider()
                }
            }

            if isStateFilterActive {
                Divider()
                Button("Show All States") {
                    commandRegistry.run("note.stateFilter.clear")
                }
                .disabled(!commandRegistry.canExecute("note.stateFilter.clear"))
            }
        }

        Button("Duplicate") {
            commandRegistry.run(
                "note.duplicate",
                arguments: CommandArguments(noteID: note.id)
            )
        }
        .disabled(
            !commandRegistry.canExecute(
                "note.duplicate",
                arguments: CommandArguments(noteID: note.id)
            )
        )

        Button("Reveal in Finder") {
            commandRegistry.run(
                "note.revealInFinder",
                arguments: CommandArguments(noteID: note.id)
            )
        }
        .disabled(
            !commandRegistry.canExecute(
                "note.revealInFinder",
                arguments: CommandArguments(noteID: note.id)
            )
        )

        Button("Delete", role: .destructive) {
            commandRegistry.run(
                "note.delete",
                arguments: CommandArguments(noteID: note.id)
            )
        }
        .disabled(
            !commandRegistry.canExecute(
                "note.delete",
                arguments: CommandArguments(noteID: note.id)
            )
        )
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
        commandRegistry.run(
            "note.select",
            arguments: CommandArguments(noteID: id)
        )
        commandRegistry.run("focus.editor")
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
        commandRegistry.run(
            "note.select",
            arguments: CommandArguments(noteID: target)
        )
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
            .frame(height: 8)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(AppTypography.caption)
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
                            .font(AppTypography.caption)
                            .foregroundStyle(.secondary.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }

            Spacer(minLength: 12)

            Menu {
                Button("All") {
                    commandRegistry.run("note.stateFilter.clear")
                }

                ForEach(NoteState.allCases, id: \.self) { state in
                    Button(state.displayName) {
                        commandRegistry.run(
                            "note.stateFilter.set",
                            arguments: CommandArguments(noteState: state)
                        )
                    }
                }
            } label: {
                Text(stateFilterLabel)
                .foregroundStyle(.secondary)
                .opacity(0.85)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .accessibilityLabel("State filter")
        }
        .font(AppTypography.secondaryBody)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
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

        let mappedResults: [SearchDisplayResult] = searchResults.compactMap { result in
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

        return NoteStateFiltering.filteredByState(
            mappedResults,
            stateFilter: uiState.noteStateFilter
        ) { $0.note.state }
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
        HStack(spacing: 8) {
            Rectangle()
                .fill(accentColor.opacity(accentOpacity))
                .frame(width: SidebarAccentPalette.stripWidth)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(isSelected ? AppTypography.secondaryBodyEmphasis : AppTypography.secondaryBody)
                    .lineLimit(1)
                    .foregroundStyle(
                        isHovered
                        ? Color.primary.opacity(0.92)
                        : Color.primary.opacity(0.82)
                    )

                if let metadataLine, !metadataLine.isEmpty {
                    Text(metadataLine)
                        .font(AppTypography.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary.opacity(0.72))
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
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
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct TagSelectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text("Choose a tag")
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(.primary.opacity(0.78))
                Text("Select a tag from the sidebar to view its notes.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("No matches for \"\(trimmed)\"")
                .font(AppTypography.captionEmphasis)
            Text("Try a different word in \(contextLabel).")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
