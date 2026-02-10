//
//  LibraryIndexReconciler.swift
//  SoftDraft
//
//  Created by Matt Adams on 10/02/2026.
//

import Foundation

enum LibraryIndexReconciler {

    struct Result {
        let index: LibraryIndex
        let changed: Bool
    }

    private struct NoteSnapshot {
        let modified: Date
        let filename: String
    }

    private struct FilesystemSnapshot {
        var collections: Set<String>
        var notes: [String: NoteSnapshot]
    }

    static func applyEvents(
        _ events: [LibraryFilesystemEvent],
        to index: LibraryIndex,
        libraryURL: URL
    ) async -> Result {
        await Task.detached(priority: .utility) {
            var next = index
            var changed = false

            for event in events {
                if apply(event, to: &next, libraryURL: libraryURL) {
                    changed = true
                }
            }

            if changed {
                next.lastUpdated = Date()
            }

            return Result(index: next, changed: changed)
        }.value
    }

    static func reconcileAgainstFilesystem(
        libraryURL: URL,
        index: LibraryIndex
    ) async -> Result {
        await Task.detached(priority: .utility) {
            let snapshot = captureFilesystemSnapshot(libraryURL: libraryURL)

            let indexNoteIDs = Set(index.notes.keys)
            let fsNoteIDs = Set(snapshot.notes.keys)

            var missingNotes = indexNoteIDs.subtracting(fsNoteIDs)
            var newNotes = fsNoteIDs.subtracting(indexNoteIDs)

            let renamePairs = detectRenamePairs(
                missingNotes: &missingNotes,
                newNotes: &newNotes,
                snapshot: snapshot,
                index: index
            )

            var events: [LibraryFilesystemEvent] = []
            events.append(contentsOf: renamePairs.map {
                .renamed(from: $0.oldID, to: $0.newID)
            })

            events.append(contentsOf: newNotes.map { .added(noteID: $0) })
            events.append(contentsOf: missingNotes.map { .deleted(noteID: $0) })

            let modifiedEvents = indexNoteIDs.intersection(fsNoteIDs).compactMap { noteID -> LibraryFilesystemEvent? in
                guard
                    let snapshotNote = snapshot.notes[noteID],
                    let indexed = index.notes[noteID]
                else { return nil }

                let delta = abs(snapshotNote.modified.timeIntervalSince(indexed.modified))
                if delta > 0.0005 {
                    return .modified(noteID: noteID)
                }
                return nil
            }
            events.append(contentsOf: modifiedEvents)

            let existingCollections = Set(index.collections.keys)
            let newCollections = snapshot.collections.subtracting(existingCollections)
            let missingCollections = existingCollections.subtracting(snapshot.collections)

            events.append(contentsOf: newCollections.map { .collectionAdded(collectionID: $0) })
            events.append(contentsOf: missingCollections.map { .collectionDeleted(collectionID: $0) })

            var next = index
            var changed = false
            for event in events {
                if apply(event, to: &next, libraryURL: libraryURL) {
                    changed = true
                }
            }

            if changed {
                next.lastUpdated = Date()
            }

            return Result(index: next, changed: changed)
        }.value
    }

    private static func apply(
        _ event: LibraryFilesystemEvent,
        to index: inout LibraryIndex,
        libraryURL: URL
    ) -> Bool {
        switch event {
        case .added(let noteID):
            return applyNoteAdded(noteID, to: &index, libraryURL: libraryURL)
        case .deleted(let noteID):
            return applyNoteDeleted(noteID, to: &index)
        case let .renamed(from, to):
            return applyNoteRenamed(from: from, to: to, index: &index, libraryURL: libraryURL)
        case .modified(let noteID):
            return applyNoteModified(noteID, to: &index, libraryURL: libraryURL)
        case let .collectionRenamed(from, to):
            return applyCollectionRenamed(from: from, to: to, index: &index, libraryURL: libraryURL)
        case let .collectionDeleted(collectionID):
            return applyCollectionDeleted(collectionID, to: &index)
        case let .collectionAdded(collectionID):
            return applyCollectionAdded(collectionID, to: &index)
        }
    }

    private static func applyNoteAdded(
        _ noteID: String,
        to index: inout LibraryIndex,
        libraryURL: URL
    ) -> Bool {
        guard let parsed = parseNoteID(noteID) else { return false }
        let collectionID = parsed.collectionID

        var changed = false

        if index.collections[collectionID] == nil {
            index.collections[collectionID] = CollectionIndex(
                id: collectionID,
                noteIDs: []
            )
            changed = true
        }

        if index.notes[noteID] == nil {
            let metadata = noteMetadata(
                noteID: noteID,
                libraryURL: libraryURL
            )
            let title = metadata?.title ?? parsed.titleFallback
            let modified = metadata?.modified ?? Date()

            index.notes[noteID] = NoteIndex(
                id: noteID,
                path: noteID,
                title: title,
                modified: modified
            )
            changed = true
        }

        if !(index.collections[collectionID]?.noteIDs.contains(noteID) ?? false) {
            index.collections[collectionID]?.noteIDs.append(noteID)
            changed = true
        }

        return changed
    }

    private static func applyNoteDeleted(
        _ noteID: String,
        to index: inout LibraryIndex
    ) -> Bool {
        var changed = false

        if index.notes.removeValue(forKey: noteID) != nil {
            changed = true
        }

        if let collectionID = parseNoteID(noteID)?.collectionID {
            if index.collections[collectionID]?.noteIDs.contains(noteID) == true {
                index.collections[collectionID]?.noteIDs.removeAll { $0 == noteID }
                changed = true
            }
        } else {
            for key in index.collections.keys {
                if index.collections[key]?.noteIDs.contains(noteID) == true {
                    index.collections[key]?.noteIDs.removeAll { $0 == noteID }
                    changed = true
                }
            }
        }

        return changed
    }

    private static func applyNoteRenamed(
        from oldID: String,
        to newID: String,
        index: inout LibraryIndex,
        libraryURL: URL
    ) -> Bool {
        guard oldID != newID else { return false }

        if index.notes[oldID] == nil {
            if index.notes[newID] != nil {
                return false
            }
            return applyNoteAdded(newID, to: &index, libraryURL: libraryURL)
        }

        let oldCollection = parseNoteID(oldID)?.collectionID
        let newCollection = parseNoteID(newID)?.collectionID

        let oldNote = index.notes.removeValue(forKey: oldID)

        if let oldCollection {
            index.collections[oldCollection]?.noteIDs.removeAll { $0 == oldID }
        }

        if let newCollection, index.collections[newCollection] == nil {
            index.collections[newCollection] = CollectionIndex(
                id: newCollection,
                noteIDs: []
            )
        }

        if let oldNote {
            let updatedModified = noteMetadata(
                noteID: newID,
                libraryURL: libraryURL
            )?.modified ?? oldNote.modified

            let updatedNote = NoteIndex(
                id: newID,
                path: newID,
                title: oldNote.title,
                modified: updatedModified
            )
            index.notes[newID] = updatedNote
        } else {
            _ = applyNoteAdded(newID, to: &index, libraryURL: libraryURL)
        }

        if let newCollection {
            if !(index.collections[newCollection]?.noteIDs.contains(newID) ?? false) {
                index.collections[newCollection]?.noteIDs.append(newID)
            }
        }

        return true
    }

    private static func applyNoteModified(
        _ noteID: String,
        to index: inout LibraryIndex,
        libraryURL: URL
    ) -> Bool {
        guard let existing = index.notes[noteID] else {
            return applyNoteAdded(noteID, to: &index, libraryURL: libraryURL)
        }

        guard let modified = noteMetadata(
            noteID: noteID,
            libraryURL: libraryURL
        )?.modified else {
            return false
        }

        let delta = abs(existing.modified.timeIntervalSince(modified))
        guard delta > 0.0005 else { return false }

        index.notes[noteID] = NoteIndex(
            id: existing.id,
            path: existing.path,
            title: existing.title,
            modified: modified
        )

        return true
    }

    private static func applyCollectionAdded(
        _ collectionID: String,
        to index: inout LibraryIndex
    ) -> Bool {
        guard index.collections[collectionID] == nil else { return false }

        index.collections[collectionID] = CollectionIndex(
            id: collectionID,
            noteIDs: []
        )
        return true
    }

    private static func applyCollectionDeleted(
        _ collectionID: String,
        to index: inout LibraryIndex
    ) -> Bool {
        var changed = false

        let noteIDs = index.collections[collectionID]?.noteIDs
            ?? index.notes.keys.filter { $0.hasPrefix("\(collectionID)/") }

        if index.collections.removeValue(forKey: collectionID) != nil {
            changed = true
        }

        for noteID in noteIDs {
            if index.notes.removeValue(forKey: noteID) != nil {
                changed = true
            }
        }

        return changed
    }

    private static func applyCollectionRenamed(
        from oldID: String,
        to newID: String,
        index: inout LibraryIndex,
        libraryURL: URL
    ) -> Bool {
        guard oldID != newID else { return false }

        let hasOldCollection = index.collections[oldID] != nil
        let hasOldNotes = index.notes.keys.contains { $0.hasPrefix("\(oldID)/") }

        guard hasOldCollection || hasOldNotes else { return false }

        if !hasOldCollection, index.collections[newID] != nil {
            return false
        }

        let existing = index.collections.removeValue(forKey: oldID)
        var noteIDs = Set(existing?.noteIDs ?? [])
        for noteID in index.notes.keys where noteID.hasPrefix("\(oldID)/") {
            noteIDs.insert(noteID)
        }

        var updatedNoteIDs: [String] = []
        updatedNoteIDs.reserveCapacity(noteIDs.count)

        for noteID in noteIDs {
            let suffix = noteID.dropFirst(oldID.count + 1)
            let newNoteID = "\(newID)/\(suffix)"

            if let oldNote = index.notes.removeValue(forKey: noteID) {
                let updatedModified = noteMetadata(
                    noteID: newNoteID,
                    libraryURL: libraryURL
                )?.modified ?? oldNote.modified

                index.notes[newNoteID] = NoteIndex(
                    id: newNoteID,
                    path: newNoteID,
                    title: oldNote.title,
                    modified: updatedModified
                )
            } else {
                _ = applyNoteAdded(newNoteID, to: &index, libraryURL: libraryURL)
            }

            updatedNoteIDs.append(newNoteID)
        }

        if index.collections[newID] == nil {
            index.collections[newID] = CollectionIndex(
                id: newID,
                noteIDs: updatedNoteIDs
            )
        } else {
            let existingIDs = index.collections[newID]?.noteIDs ?? []
            let merged = Array(Set(existingIDs).union(updatedNoteIDs))
            index.collections[newID]?.noteIDs = merged
        }

        return true
    }

    private static func parseNoteID(
        _ noteID: String
    ) -> (collectionID: String, filename: String, titleFallback: String)? {
        let parts = noteID.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let collectionID = String(parts[0])
        let filename = String(parts[1])
        guard !collectionID.isEmpty, filename.lowercased().hasSuffix(".md") else {
            return nil
        }

        let titleFallback = filename
            .replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)

        return (collectionID, filename, titleFallback)
    }

    private static func noteMetadata(
        noteID: String,
        libraryURL: URL
    ) -> (modified: Date, title: String)? {
        guard let parsed = parseNoteID(noteID) else { return nil }

        let url = libraryURL
            .appendingPathComponent(CollectionStore.collectionsDir)
            .appendingPathComponent(parsed.collectionID)
            .appendingPathComponent(parsed.filename)

        guard let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .contentModificationDateKey]
        ), values.isRegularFile == true else {
            return nil
        }

        let modified = values.contentModificationDate ?? Date()
        let title = url.deletingPathExtension().lastPathComponent
        return (modified, title)
    }

    private static func captureFilesystemSnapshot(
        libraryURL: URL
    ) -> FilesystemSnapshot {
        let collectionsURL = libraryURL
            .appendingPathComponent(CollectionStore.collectionsDir)

        let collectionURLs = (try? FileManager.default.contentsOfDirectory(
            at: collectionsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var collections = Set<String>()
        var notes: [String: NoteSnapshot] = [:]

        for collectionURL in collectionURLs {
            let values = try? collectionURL.resourceValues(
                forKeys: [.isDirectoryKey]
            )
            guard values?.isDirectory == true else { continue }

            let collectionID = collectionURL.lastPathComponent
            guard !collectionID.isEmpty else { continue }
            collections.insert(collectionID)

            let noteURLs = (try? FileManager.default.contentsOfDirectory(
                at: collectionURL,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for noteURL in noteURLs {
                guard noteURL.pathExtension.lowercased() == "md" else { continue }
                let noteValues = try? noteURL.resourceValues(
                    forKeys: [.isRegularFileKey, .contentModificationDateKey]
                )
                guard noteValues?.isRegularFile == true else { continue }

                let filename = noteURL.lastPathComponent
                let noteID = "\(collectionID)/\(filename)"
                let modified = noteValues?.contentModificationDate ?? Date()

                notes[noteID] = NoteSnapshot(
                    modified: modified,
                    filename: filename
                )
            }
        }

        return FilesystemSnapshot(
            collections: collections,
            notes: notes
        )
    }

    private static func detectRenamePairs(
        missingNotes: inout Set<String>,
        newNotes: inout Set<String>,
        snapshot: FilesystemSnapshot,
        index: LibraryIndex
    ) -> [(oldID: String, newID: String)] {
        var pairs: [(oldID: String, newID: String)] = []
        var newByFilename: [String: [String]] = [:]
        var usedNewIDs = Set<String>()

        for noteID in newNotes {
            let filename = snapshot.notes[noteID]?.filename
                ?? (noteID as NSString).lastPathComponent
            newByFilename[filename, default: []].append(noteID)
        }

        let threshold: TimeInterval = 1.0

        for oldID in missingNotes {
            let filename = (oldID as NSString).lastPathComponent
            guard let candidates = newByFilename[filename], candidates.count == 1 else {
                continue
            }

            let newID = candidates[0]
            guard !usedNewIDs.contains(newID) else { continue }
            guard
                let oldNote = index.notes[oldID],
                let newSnapshot = snapshot.notes[newID]
            else {
                continue
            }

            let delta = abs(oldNote.modified.timeIntervalSince(newSnapshot.modified))
            guard delta <= threshold else { continue }

            pairs.append((oldID: oldID, newID: newID))
            usedNewIDs.insert(newID)
        }

        for pair in pairs {
            missingNotes.remove(pair.oldID)
            newNotes.remove(pair.newID)
        }

        return pairs
    }
}
