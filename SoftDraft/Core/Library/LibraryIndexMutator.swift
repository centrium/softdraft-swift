//
//  LibraryIndexMutator.swift
//  SoftDraft
//
//  Created by Matt Adams on 10/02/2026.
//

import Foundation

enum LibraryIndexMutator {

    struct FilesystemNoteData {
        let title: String?
        let modified: Date?
        let baseNote: NoteIndex?

        init(
            title: String? = nil,
            modified: Date? = nil,
            baseNote: NoteIndex? = nil
        ) {
            self.title = title
            self.modified = modified
            self.baseNote = baseNote
        }
    }

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
            modified: Date(),
            pinned: false
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
        if let existing = next.notes[noteID] {
            next.applyTagDelta(
                oldTags: Set(existing.tags),
                newTags: []
            )
        }
        next.notes.removeValue(forKey: noteID)
        next.collections[collectionID]?.noteIDs.removeAll { $0 == noteID }
        next.lastUpdated = Date()
        return next
    }

    static func renameNote(
        index: LibraryIndex,
        oldID: String,
        newID: String,
        filesystemData: FilesystemNoteData? = nil,
        libraryURL: URL? = nil
    ) -> LibraryIndex {
        var next = index

        guard let oldNote = next.notes[oldID] else { return next }

        let oldCollection = collectionID(for: oldID)
        let newCollection = collectionID(for: newID)

        next.notes.removeValue(forKey: oldID)
        next.collections[oldCollection]?.noteIDs.removeAll { $0 == oldID }

        let modified = filesystemData?.modified ?? Date()
        let data = FilesystemNoteData(
            title: filesystemData?.title,
            modified: modified,
            baseNote: oldNote
        )

        next = updateNoteFromFilesystem(
            index: next,
            noteID: newID,
            filesystemData: data,
            libraryURL: libraryURL
        )

        if next.collections[newCollection] == nil {
            next.collections[newCollection] = CollectionIndex(
                id: newCollection,
                noteIDs: []
            )
        }

        if !(next.collections[newCollection]?.noteIDs.contains(newID) ?? false) {
            next.collections[newCollection]?.noteIDs.append(newID)
        }

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
                    modified: Date(),
                    pinned: oldNote.pinned,
                    tags: oldNote.tags
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
            if let existing = next.notes[noteID] {
                next.applyTagDelta(
                    oldTags: Set(existing.tags),
                    newTags: []
                )
            }
            next.notes.removeValue(forKey: noteID)
        }

        next.lastUpdated = Date()
        return next
    }

    static func updateNoteFromFilesystem(
        index: LibraryIndex,
        noteID: String,
        filesystemData: FilesystemNoteData,
        libraryURL: URL? = nil
    ) -> LibraryIndex {
        var next = index

        let existing = next.notes[noteID] ?? filesystemData.baseNote
        let oldTags = Set(existing?.tags ?? [])
        var newTags = oldTags

        let shouldParseTags = existing == nil || next.notes[noteID] != nil
        if shouldParseTags, let libraryURL {
            let noteURL = libraryURL
                .appendingPathComponent(CollectionStore.collectionsDir)
                .appendingPathComponent(noteID)

            if let markdown = try? String(contentsOf: noteURL, encoding: .utf8) {
                newTags = TagParser.parseTags(from: markdown)
            }
        }

        next.applyTagDelta(oldTags: oldTags, newTags: newTags)
        let sortedTags = Array(newTags).sorted()

        if let existing {
            let updated = NoteIndex(
                id: noteID,
                path: noteID,
                title: filesystemData.title ?? existing.title,
                modified: filesystemData.modified ?? existing.modified,
                pinned: existing.pinned,
                tags: sortedTags
            )
            next.notes[noteID] = updated
            return next
        }

        let title = filesystemData.title ?? titleFallback(for: noteID)
        let modified = filesystemData.modified ?? Date()

        next.notes[noteID] = NoteIndex(
            id: noteID,
            path: noteID,
            title: title,
            modified: modified,
            pinned: false,
            tags: sortedTags
        )

        return next
    }

    static func togglePin(
        index: LibraryIndex,
        noteID: String
    ) -> LibraryIndex {
        var next = index
        guard let existing = next.notes[noteID] else { return next }

        next.notes[noteID] = NoteIndex(
            id: existing.id,
            path: existing.path,
            title: existing.title,
            modified: existing.modified,
            pinned: !existing.pinned,
            tags: existing.tags
        )

        next.lastUpdated = Date()
        return next
    }

    static func setPinned(
        index: LibraryIndex,
        noteID: String,
        pinned: Bool
    ) -> LibraryIndex {
        var next = index
        guard let existing = next.notes[noteID] else { return next }
        guard existing.pinned != pinned else { return next }

        next.notes[noteID] = NoteIndex(
            id: existing.id,
            path: existing.path,
            title: existing.title,
            modified: existing.modified,
            pinned: pinned,
            tags: existing.tags
        )

        next.lastUpdated = Date()
        return next
    }

    private static func collectionID(for noteID: String) -> String {
        noteID.split(separator: "/").first.map(String.init) ?? "Inbox"
    }

    private static func titleFallback(for noteID: String) -> String {
        let filename = (noteID as NSString).lastPathComponent
        return filename.replacingOccurrences(
            of: ".md",
            with: "",
            options: .caseInsensitive
        )
    }
}
