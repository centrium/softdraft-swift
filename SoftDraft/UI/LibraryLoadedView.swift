//
//  LibraryLoadedView.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

import SwiftUI
import Combine

struct LibraryLoadedView: View {

    let libraryURL: URL

    @EnvironmentObject private var selection: SelectionModel
    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry
    @EnvironmentObject private var uiState: UIState

    @State private var collectionSummaries: [String: CollectionLandingSummary] = [:]
    @State private var imageErrorDismissTask: Task<Void, Never>? = nil
    @FocusState private var editorFocused: Bool

    private func requestEditorFocus() {
        guard selection.selectedNoteID != nil else {
            editorFocused = false
            return
        }

        editorFocused = false
        DispatchQueue.main.async {
            guard uiState.requestedFocusRegion == .editor else { return }
            guard selection.selectedNoteID != nil else { return }
            editorFocused = true
        }
    }

    private var selectedCollection: String {
        selection.selectedCollectionID ?? "Inbox"
    }

    private var landingSummary: CollectionLandingSummary? {
        collectionSummaries[selectedCollection]
    }

    private var isMoveSheetPresented: Binding<Bool> {
        Binding(
            get: { selection.pendingMove != nil },
            set: { isPresented in
                guard !isPresented else { return }
                commandRegistry.run("command.cancel")
            }
        )
    }

    private var moveDestinationCollections: [String] {
        var names = Set(libraryManager.visibleCollections)
        if let pending = selection.pendingMove {
            names.insert(collectionID(for: pending.noteID))
        }
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var isNoteSelected: Bool {
        selection.selectedNoteID != nil
    }

    private var selectedNoteSummary: NoteSummary? {
        guard let selectedNoteID = selection.selectedNoteID else { return nil }
        return libraryManager.visibleNotes.first { $0.id == selectedNoteID }
    }

    private var currentShareContent: String {
        guard isNoteSelected else { return "" }

        if !libraryManager.currentNoteText.isEmpty {
            return libraryManager.currentNoteText
        }

        if let selectedNoteSummary,
           let markdown = libraryManager.markdownForNote(selectedNoteSummary) {
            return markdown
        }

        return libraryManager.currentNoteText
    }

    private var canShareCurrentNote: Bool {
        isNoteSelected && !currentShareContent.isEmpty
    }

    // ─────────────────────────────
    // Sidebar toolbar
    // ─────────────────────────────
    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {

        // Toggle Collections / Tags
        ToolbarItem(placement: .primaryAction) {
            Button {
                if uiState.sidebarMode == .collections {
                    commandRegistry.run("sidebar.showTags")
                } else {
                    commandRegistry.run("sidebar.showCollections")
                }
            } label: {
                Image(systemName:
                    uiState.sidebarMode == .collections
                    ? "tag"
                    : "folder"
                )
                .offset(y: 1)
            }
            .help(
                uiState.sidebarMode == .collections
                ? "Show Tags"
                : "Show Collections"
            )
        }

        // New note
        ToolbarItem(placement: .primaryAction) {
            Button {
                commandRegistry.run("note.create")
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("New Note")
        }

    }

    @ToolbarContentBuilder
    private var shareToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
                ShareLink(item: currentShareContent) {
                    Image(systemName: "square.and.arrow.up")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .disabled(!canShareCurrentNote)
                .opacity(canShareCurrentNote ? 1 : 0.45)
                .help("Share")
            }
        
    }

    // ─────────────────────────────
    // Body
    // ─────────────────────────────
    var body: some View {
        ZStack {
            normalLayout
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.22), value: uiState.isZenModeEnabled)
        .onChange(of: uiState.imageInsertionError) { _, newValue in
            imageErrorDismissTask?.cancel()
            guard let message = newValue, !message.isEmpty else { return }

            imageErrorDismissTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    if uiState.imageInsertionError == message {
                        uiState.imageInsertionError = nil
                    }
                }
            }
        }
        .onDisappear {
            imageErrorDismissTask?.cancel()
            imageErrorDismissTask = nil
        }
        .onChange(of: libraryManager.currentNoteText) { _, _ in
            uiState.imageInsertionError = nil
        }
        .onReceive(uiState.$focusRequestToken.dropFirst()) { _ in
            guard uiState.requestedFocusRegion == .editor else {
                editorFocused = false
                return
            }
            uiState.setSurface(.editor)
            guard selection.selectedNoteID != nil else {
                editorFocused = false
                return
            }
            requestEditorFocus()
        }
        .onChange(of: selection.selectedNoteID) { _, newValue in
            guard newValue != nil else {
                editorFocused = false
                return
            }
            guard !uiState.isPreviewModeEnabled else {
                editorFocused = false
                return
            }
            guard uiState.requestedFocusRegion == .editor else { return }
            requestEditorFocus()
        }
        .onChange(of: selection.selectedCollectionID) { oldValue, newValue in
            guard oldValue != newValue else { return }
            guard uiState.noteStateFilter != nil else { return }
            commandRegistry.run("note.stateFilter.clear")
        }
        .onChange(of: editorFocused) { _, isFocused in
            if isFocused {
                uiState.activeFocusRegion = .editor
            }
        }
    }
}

// MARK: - Layout

private extension LibraryLoadedView {

    var normalLayout: some View {
        NavigationSplitView(columnVisibility: $uiState.splitViewVisibility) {

            LibraryRailView(libraryURL: libraryURL)
                .navigationSplitViewColumnWidth(
                    min: 280,
                    ideal: 320,
                    max: 360
                )
                .toolbar {
                    sidebarToolbar
                }

        } detail: {

            // ⬇️ Editor + Preview layering happens here
            layeredEditor
                .toolbar {
                    shareToolbar
                }
                .sheet(isPresented: isMoveSheetPresented) {
                    if let pending = selection.pendingMove {
                        MoveNoteSheet(
                            currentCollection: collectionID(for: pending.noteID),
                            noteCount: 1,
                            collections: moveDestinationCollections,
                            onMove: { destination in
                                commandRegistry.run(
                                    "note.move.confirm",
                                    arguments: CommandArguments(
                                        noteID: pending.noteID,
                                        collectionID: destination
                                    )
                                )
                            },
                            onCancel: {
                                commandRegistry.run("command.cancel")
                            }
                        )
                    } else {
                        EmptyView()
                    }
                }
        }
        .onReceive(libraryManager.$visibleNotes) { notes in
            guard let activeCollection = libraryManager.visibleCollectionID else { return }
            collectionSummaries[activeCollection] = makeSummary(
                for: activeCollection,
                notes: notes
            )
        }
    }
}

// MARK: - Layered Editor / Preview

private extension LibraryLoadedView {

    var layeredEditor: some View {
        ZStack {

            // ───────── Editor (always mounted) ─────────
            editorStack
                .allowsHitTesting(
                    !(uiState.isPreviewModeEnabled && selection.selectedNoteID != nil)
                )
                .opacity(
                    uiState.isPreviewModeEnabled && selection.selectedNoteID != nil
                    ? 0
                    : 1
                )
                .onChange(of: uiState.isPreviewModeEnabled) { _, isPreview in
                    if isPreview {
                        editorFocused = false
                    }
                }

            // ───────── Preview overlay ─────────
            previewStack
                .opacity(
                    uiState.isPreviewModeEnabled && selection.selectedNoteID != nil
                    ? 1
                    : 0
                )
                .allowsHitTesting(uiState.isPreviewModeEnabled)
                .focusable(false)
        }
    }
}

// MARK: - Editor Stack

private extension LibraryLoadedView {

    var editorStack: some View {
        ZStack {

            // Editor content
            PersistentEditorHost(
                noteID: selection.selectedNoteID,
                sourceText: libraryManager.currentNoteText
            )
                .focused($editorFocused)
                .opacity(selection.selectedNoteID == nil ? 0 : 1)
                .mask(editorFadeMask)

            // Landing view (no note selected)
            if selection.selectedNoteID == nil {
                CollectionLandingView(
                    collectionName: selectedCollection,
                    summary: landingSummary
                )
                .allowsHitTesting(true)
                .transition(.opacity)
            }

            if uiState.isInsertingImage {
                imageInsertionOverlay
                    .transition(.opacity)
            }
            
            if let message = uiState.imageInsertionError {
                imageInsertionErrorBanner(message: message)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Preview Stack (mock)

private extension LibraryLoadedView {
    
    var previewStack: some View {
        NotePreviewSurface(
            noteID: selection.selectedNoteID,
            text: libraryManager.currentNoteText
        )
            .id(selection.selectedNoteID ?? "__no-note-preview__")
            .mask(editorFadeMask)
    }
}

// MARK: - Helpers

private extension LibraryLoadedView {

    func makeSummary(
        for collectionID: String,
        notes: [NoteSummary]
    ) -> CollectionLandingSummary {
        let latestDate = notes.map(\.modifiedAt).max()
        return CollectionLandingSummary(
            noteCount: notes.count,
            lastUpdated: latestDate
        )
    }

    func collectionID(for noteID: String) -> String {
        let collectionID = (noteID as NSString).deletingLastPathComponent
        return collectionID.isEmpty ? "Inbox" : collectionID
    }

    var imageInsertionOverlay: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Inserting image…")
                        .font(.footnote)
                        .bold()
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 8, y: 3)
            }
            Spacer()
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: uiState.isInsertingImage)
    }
    
    @ViewBuilder
    func imageInsertionErrorBanner(message: String) -> some View {
        VStack {
            HStack {
                Spacer()
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .imageScale(.medium)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Image couldn’t be inserted")
                            .font(.callout.weight(.semibold))
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
            }
            Spacer()
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
    }
}

private var topFadeMask: some View {
    LinearGradient(
        colors: [
            Color.clear,   // fully transparent at very top
            Color.black,   // fully opaque
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    .frame(height: 60)   // controls how gradual the fade is
}

private var editorFadeMask: some View {
    VStack(spacing: 0) {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 48)

        Rectangle() // fully opaque remainder
    }
}
