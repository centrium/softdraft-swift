//
//  NotesListView.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

private enum NotesSection: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case older = "Older"
}

private func section(for date: Date) -> NotesSection {
    let calendar = Calendar.current

    if calendar.isDateInToday(date) {
        return .today
    }

    if calendar.isDateInYesterday(date) {
        return .yesterday
    }

    if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
        return .thisWeek
    }

    return .older
}

struct NotesListView: View {

    let libraryURL: URL
    let collection: String

    private enum FocusField {
        case search
        case results
    }

    @EnvironmentObject private var selection: SelectionModel
    @State private var listSelection: String?

    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry
    @EnvironmentObject private var searchIndex: SearchIndex

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
    
    private var groupedNotes: [NotesSection: [NoteSummary]] {
        Dictionary(
            grouping: libraryManager.visibleNotes,
            by: { section(for: $0.modifiedAt) }
        )
    }

    private var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeSelectionBinding: Binding<String?> {
        if isSearchActive {
            return Binding(
                get: { searchSelection },
                set: { newValue in
                    guard searchSelection != newValue else { return }
                    searchSelection = newValue
                }
            )
        }

        return listSelectionBinding
    }
    
    var body: some View {
        ZStack {

            VStack(spacing: 0) {
                searchField

                List(selection: activeSelectionBinding) {
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
                                collection: collection
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
                                        hint: result.hint,
                                        isSelected: searchSelection == result.id
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(minHeight: 48)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            searchSelection == result.id
                                            ? Color.primary.opacity(0.12)
                                            : result.isHovered
                                            ? Color.primary.opacity(0.06)
                                            : Color.clear
                                        )
                                )
                                .listRowInsets(
                                    EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
                                )
                                .listRowSeparator(.hidden)
                                .tag(result.id)
                                .onHover { hovering in
                                    updateHoverState(for: result.id, hovering: hovering)
                                }
                            }
                        }

                    } else if libraryManager.visibleNotes.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                commandRegistry.run("note.create")
                            } label: {
                                Label("New note", systemImage: "plus")
                                    .font(.system(size: 14, weight: .medium))
                                    .opacity(0.8)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(NotesSection.allCases, id: \.self) { section in
                            if let notes = groupedNotes[section], !notes.isEmpty {

                                Section {
                                    ForEach(notes, id: \.id) { note in
                                        NoteRow(note: note)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .frame(minHeight: 44) // keeps selection stable
                                            .listRowBackground(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(
                                                        selection.selectedNoteID == note.id
                                                        ? Color.primary.opacity(0.08)
                                                        : Color.clear
                                                    )
                                            )
                                            .listRowInsets(
                                                EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
                                            )
                                            .tag(note.id)
                                    }
                                } header: {
                                    Text(section.rawValue)
                                        .font(.caption)
                                        .tracking(0.6)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 2)
                                }
                            }
                        }
                    }
                }
                .focused($focusedField, equals: .results)
                .listStyle(.sidebar)
                .navigationTitle(collection)
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
                .task {
                    await libraryManager.loadNotes(
                        libraryURL: libraryURL,
                        collection: collection
                    )
                    prefetchInitialNotes()
                }
                .onChange(of: collection) { _, newCollection in
                    clearSearch()
                    selection.selectCollection(newCollection)
                    Task {
                        await libraryManager.loadNotes(
                            libraryURL: libraryURL,
                            collection: newCollection
                        )
                        prefetchInitialNotes()
                    }
                    
                }
                .onAppear {
                    syncSelectionFromModel()
                }
                .onChange(of: selection.selectedNoteID) { _, newValue in
                    guard listSelection != newValue else { return }
                    listSelection = newValue
                }
                .onChange(of: listSelection) { _, newValue in
                    guard !isSearchActive else { return }
                    guard selection.selectedNoteID != newValue else { return }
                    Task { @MainActor in
                        selection.selectedNoteID = newValue
                    }
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

    private var listSelectionBinding: Binding<String?> {
        Binding(
            get: { listSelection },
            set: { newValue in
                guard listSelection != newValue else { return }
                listSelection = newValue
            }
        )
    }

    private func syncSelectionFromModel() {
        guard listSelection != selection.selectedNoteID else { return }
        listSelection = selection.selectedNoteID
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

        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }

            let results = searchIndex.search(trimmed)
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
        syncSelectionFromModel()
    }

    private func openSearchResult(_ id: String) {
        selection.selectedNoteID = id
        listSelection = id
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

    private func updateHoverState(for id: String, hovering: Bool) {
        if hovering {
            hoveredSearchResult = id
        } else if hoveredSearchResult == id {
            hoveredSearchResult = nil
        }
    }

    private func prefetchInitialNotes() {
        guard let libraryURL = libraryManager.activeLibraryURL else { return }
        guard libraryManager.visibleCollectionID == collection else { return }

        let targets = libraryManager.visibleNotes
            .prefix(3)
            .map(\.id)

        guard !targets.isEmpty else { return }

        Task {
            for id in targets {
                await NotePrefetchCache.shared.preload(
                    libraryURL: libraryURL,
                    noteID: id
                )
            }
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

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
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    focusedField == .search
                    ? Color.accentColor.opacity(0.4)
                    : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
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

        return searchResults.compactMap { result in
            guard let note = notesByID[result.id] else { return nil }
            return SearchDisplayResult(
                id: result.id,
                note: note,
                score: result.score,
                hint: SearchHint(matchHint: result.matchHint),
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
}

private struct SearchHint: Equatable {
    let label: String
    let rank: Int

    init?(matchHint: String?) {
        guard let hint = matchHint else { return nil }
        if hint == "Title" {
            label = "Title match"
            rank = 0
        } else if hint == "Body" {
            label = "Body match"
            rank = 2
        } else {
            label = "Heading match"
            rank = 1
        }
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
    let hint: SearchHint?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title)
                .font(.body)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(note.modifiedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let hint {
                    Text(hint.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                    ? Color.primary.opacity(0.18)
                                    : Color.primary.opacity(0.08)
                                )
                        )
                }

            }
        }
        .padding(.vertical, 4)
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

private struct SearchEmptyState: View {
    let query: String
    let collection: String

    var body: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 6) {
            Text("No matches for \"\(trimmed)\"")
                .font(.body.weight(.medium))
            Text("Try a different word in \(collection).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct NewNoteRow: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))

                Text("New note")
                    .font(.system(size: 14))
                    .opacity(0.75)

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.06) : .clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
