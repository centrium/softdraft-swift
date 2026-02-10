//
//  LibraryIndexMutator.swift
//  SoftDraft
//
//  Created by Matt Adams on 10/02/2026.
//

import Foundation

enum LibraryIndexMutator {

    static func createNote(
        index: LibraryIndex,
        noteID: String,
        title: String,
        collectionID: String
    ) -> LibraryIndex {
        var next = index

        if next.collections[collectionID] == nil {
            next.collections[collectionID] = CollectionIndex(
                id: collectionID,
                noteIDs: []
            )
        }

        next.notes[noteID] = NoteIndex(
            id: noteID,
            path: noteID,
            title: title,
            modified: Date()
        )

        if !(next.collections[collectionID]?.noteIDs.contains(noteID) ?? false) {
            next.collections[collectionID]?.noteIDs.append(noteID)
        }

        next.lastUpdated = Date()
        return next
    }

    static func deleteNote(
        index: LibraryIndex,
        noteID: String,
        collectionID: String
    ) -> LibraryIndex {
        var next = index
        next.notes.removeValue(forKey: noteID)
        next.collections[collectionID]?.noteIDs.removeAll { $0 == noteID }
        next.lastUpdated = Date()
        return next
    }

    static func renameNote(
        index: LibraryIndex,
        oldID: String,
        newID: String
    ) -> LibraryIndex {
        var next = index

        guard let oldNote = next.notes[oldID] else { return next }

        let oldCollection = collectionID(for: oldID)
        let newCollection = collectionID(for: newID)

        next.notes.removeValue(forKey: oldID)
        next.collections[oldCollection]?.noteIDs.removeAll { $0 == oldID }

        let newNote = NoteIndex(
            id: newID,
            path: newID,
            title: oldNote.title,
            modified: Date()
        )

        next.notes[newID] = newNote

        if next.collections[newCollection] == nil {
            next.collections[newCollection] = CollectionIndex(
                id: newCollection,
                noteIDs: []
            )
        }

        next.collections[newCollection]?.noteIDs.append(newID)

        next.lastUpdated = Date()
        return next
    }

    static func createCollection(
        index: LibraryIndex,
        collectionID: String
    ) -> LibraryIndex {
        var next = index

        if next.collections[collectionID] == nil {
            next.collections[collectionID] = CollectionIndex(
                id: collectionID,
                noteIDs: []
            )
        }

        next.lastUpdated = Date()
        return next
    }

    static func renameCollection(
        index: LibraryIndex,
        oldID: String,
        newID: String
    ) -> LibraryIndex {
        var next = index
        guard oldID != newID else { return next }

        let oldCollection = next.collections.removeValue(forKey: oldID)
        let oldNoteIDs = oldCollection?.noteIDs ?? []

        var updatedNoteIDs: [String] = []
        updatedNoteIDs.reserveCapacity(oldNoteIDs.count)

        for noteID in oldNoteIDs {
            let newNoteID: String
            if noteID.hasPrefix("\(oldID)/") {
                let rest = noteID.dropFirst(oldID.count + 1)
                newNoteID = "\(newID)/\(rest)"
            } else {
                newNoteID = noteID
            }

            if let oldNote = next.notes.removeValue(forKey: noteID) {
                let updatedNote = NoteIndex(
                    id: newNoteID,
                    path: newNoteID,
                    title: oldNote.title,
                    modified: Date()
                )
                next.notes[newNoteID] = updatedNote
            }

            updatedNoteIDs.append(newNoteID)
        }

        next.collections[newID] = CollectionIndex(
            id: newID,
            noteIDs: updatedNoteIDs
        )

        next.lastUpdated = Date()
        return next
    }

    static func deleteCollection(
        index: LibraryIndex,
        collectionID: String
    ) -> LibraryIndex {
        var next = index

        let noteIDs = next.collections[collectionID]?.noteIDs
            ?? next.notes.keys.filter { $0.hasPrefix("\(collectionID)/") }

        next.collections.removeValue(forKey: collectionID)

        for noteID in noteIDs {
            next.notes.removeValue(forKey: noteID)
        }

        next.lastUpdated = Date()
        return next
    }

    private static func collectionID(for noteID: String) -> String {
        noteID.split(separator: "/").first.map(String.init) ?? "Inbox"
    }
}
