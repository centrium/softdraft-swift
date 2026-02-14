//
//  LibraryManager+Notes.swift
//  SoftDraft
//

import Foundation

extension LibraryManager {

    // MARK: - Notes loading

    func loadNotes(
        libraryURL: URL,
        collection: String
    ) async {
        guard activeLibraryURL == libraryURL else { return }
        selectCollection(collection)
    }

    func loadNotesFromIndex(
        collection: String
    ) {
        selectCollection(collection)
    }

    func reloadCurrentCollection(
        preferredSelection: String? = nil,
        enforceSelection: Bool = false
    ) {
        updateVisibleNotes()
        validateSelectionInVisibleNotes()

        if enforceSelection {
            finalizeSelectionAfterRemoval(preferred: preferredSelection)
        }
    }

    @discardableResult
    func prepareSelectionForRemoval(of noteID: String) -> (preferredNextID: String?, affectedVisibleList: Bool) {
        guard let index = visibleNotes.firstIndex(where: { $0.id == noteID }) else {
            return (nil, false)
        }

        let preferred = neighborID(around: index)

        if let preferred {
            selection?.selectNote(preferred)
        } else if visibleNotes.count == 1 {
            selection?.selectNote(nil)
        }

        return (preferred, true)
    }

    private func finalizeSelectionAfterRemoval(preferred: String?) {
        if visibleNotes.isEmpty {
            selection?.selectNote(nil)
            return
        }

        if let current = selection?.selectedNoteID,
           visibleNotes.contains(where: { $0.id == current }) {
            return
        }

        if let preferred,
           visibleNotes.contains(where: { $0.id == preferred }) {
            selection?.selectNote(preferred)
            return
        }

        selection?.selectNote(visibleNotes.first?.id)
    }

    private func neighborID(around index: Int) -> String? {
        if index + 1 < visibleNotes.count {
            return visibleNotes[index + 1].id
        }

        if index > 0 {
            return visibleNotes[index - 1].id
        }

        return nil
    }

    // MARK: - Note mutations

    func createNote(
        in collectionID: String,
        libraryURL: URL
    ) async -> String? {

        beginInternalWrite()
        defer { endInternalWrite() }

        let result: (summary: NoteSummary, content: String)

        do {
            result = try NoteStore.create(
                libraryURL: libraryURL,
                collection: collectionID,
                title: "Untitled"
            )
        } catch {
            print("Failed to create note:", error)
            return nil
        }

        updateLibraryIndexAfterCreateNote(
            noteID: result.summary.id,
            title: result.summary.title,
            collectionID: collectionID
        )
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()

        return result.summary.id
    }

    func deleteNote(
        _ noteID: String,
        from collectionID: String,
        libraryURL: URL
    ) async {

        let selectionPlan = prepareSelectionForRemoval(of: noteID)

        beginInternalWrite(noteID: noteID)
        defer { endInternalWrite(noteID: noteID) }

        do {
            _ = try NoteStore.delete(
                libraryURL: libraryURL,
                noteID: noteID
            )
        } catch {
            print("Failed to delete note:", error)
        }

        updateLibraryIndexAfterDeleteNote(noteID: noteID, collectionID: collectionID)
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()

        if selectionPlan.affectedVisibleList {
            finalizeSelectionAfterRemoval(preferred: selectionPlan.preferredNextID)
        }
    }

    func togglePin(
        noteID: String
    ) {
        guard
            let libraryURL = activeLibraryURL,
            let index = libraryIndex
        else { return }

        libraryIndex = LibraryIndexMutator.togglePin(
            index: index,
            noteID: noteID
        )
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
    }
}
