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

    @EnvironmentObject private var selection: SelectionModel
    @State private var listSelection: String?

    @EnvironmentObject private var libraryManager: LibraryManager
    @EnvironmentObject private var commandRegistry: CommandRegistry
    
    private var collections: [String] {
        libraryManager.allCollections()
    }
    
    var body: some View {
        ZStack {

            // ─────────────────────────────
            // Main notes list
            // ─────────────────────────────
                List(selection: listSelectionBinding) {
                    if libraryManager.visibleNotes.isEmpty {
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
                            ForEach(libraryManager.visibleNotes, id: \.id) { note in
                                NoteRow(note: note)
                                    .tag(note.id)
                            }
                        }
                }
                .navigationTitle(collection)
                .task {
                    await libraryManager.loadNotes(
                        libraryURL: libraryURL,
                        collection: collection
                    )
                    prefetchInitialNotes()
                }
                .onChange(of: collection) { _, newCollection in
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
                    selection.selectCollection(collection)
                    syncSelectionFromModel()
                }
                .onChange(of: selection.selectedNoteID) { _, newValue in
                    guard listSelection != newValue else { return }
                    listSelection = newValue
                }
                .onChange(of: listSelection) { _, newValue in
                    guard selection.selectedNoteID != newValue else { return }
                    Task { @MainActor in
                        selection.selectedNoteID = newValue
                    }
                }
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
