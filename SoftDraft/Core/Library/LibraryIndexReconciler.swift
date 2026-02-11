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

    struct NoteSnapshot {
        let modified: Date
        let filename: String
    }

    struct FilesystemSnapshot {
        var collections: Set<String>
        var notes: [String: NoteSnapshot]
    }

    static func applyEvents(
        _ events: [LibraryFilesystemEvent],
        to index: LibraryIndex,
        libraryURL: URL
    ) async -> Result {
        let provider: NoteMetadataProvider = { noteID in
            noteMetadata(noteID: noteID, libraryURL: libraryURL)
        }
        return await applyEvents(events, to: index, metadataProvider: provider)
    }

    static func reconcileAgainstFilesystem(
        libraryURL: URL,
        index: LibraryIndex
    ) async -> Result {
        await Task.detached(priority: .utility) {
            let snapshot = captureFilesystemSnapshot(libraryURL: libraryURL)
            return reconcileAgainstSnapshot(snapshot: snapshot, index: index)
        }.value
    }

    static func reconcileAgainstSnapshot(
        snapshot: FilesystemSnapshot,
        index: LibraryIndex
    ) -> Result {
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

        let provider: NoteMetadataProvider = { noteID in
            guard let note = snapshot.notes[noteID] else { return nil }
            let title = note.filename
                .replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)
            return (note.modified, title)
        }

        return applyEventsSync(
            events,
            to: index,
            metadataProvider: provider
        )
    }

    static func applyEvents(
        _ events: [LibraryFilesystemEvent],
        to index: LibraryIndex,
        metadataProvider: @escaping NoteMetadataProvider
    ) async -> Result {
        await Task.detached(priority: .utility) {
            applyEventsSync(events, to: index, metadataProvider: metadataProvider)
        }.value
    }

    typealias NoteMetadataProvider = @Sendable (String) -> (modified: Date, title: String)?

    private static func apply(
        _ event: LibraryFilesystemEvent,
        to index: inout LibraryIndex,
        metadataProvider: @escaping NoteMetadataProvider
    ) -> Bool {
        switch event {
        case .added(let noteID):
            return applyNoteAdded(noteID, to: &index, metadataProvider: metadataProvider)
        case .deleted(let noteID):
            return applyNoteDeleted(noteID, to: &index)
        case let .renamed(from, to):
            return applyNoteRenamed(from: from, to: to, index: &index, metadataProvider: metadataProvider)
        case .modified(let noteID):
            return applyNoteModified(noteID, to: &index, metadataProvider: metadataProvider)
        case let .collectionRenamed(from, to):
            return applyCollectionRenamed(from: from, to: to, index: &index, metadataProvider: metadataProvider)
        case let .collectionDeleted(collectionID):
            return applyCollectionDeleted(collectionID, to: &index)
        case let .collectionAdded(collectionID):
            return applyCollectionAdded(collectionID, to: &index)
        }
    }

    private static func applyNoteAdded(
        _ noteID: String,
        to index: inout LibraryIndex,
        metadataProvider: @escaping NoteMetadataProvider
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

        let metadata = metadataProvider(noteID)
        let title = metadata?.title ?? parsed.titleFallback
        let modified = metadata?.modified ?? Date()

        if let existing = index.notes[noteID] {
            let delta = abs(existing.modified.timeIntervalSince(modified))
            if delta > 0.0005 || existing.title != title || existing.path != noteID {
                index = LibraryIndexMutator.updateNoteFromFilesystem(
                    index: index,
                    noteID: noteID,
                    filesystemData: .init(title: title, modified: modified)
                )
                changed = true
            }
        } else {
            index = LibraryIndexMutator.updateNoteFromFilesystem(
                index: index,
                noteID: noteID,
                filesystemData: .init(title: title, modified: modified)
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
        metadataProvider: @escaping NoteMetadataProvider
    ) -> Bool {
        guard oldID != newID else { return false }

        if index.notes[oldID] == nil {
            if index.notes[newID] != nil {
                return false
            }
            return applyNoteAdded(newID, to: &index, metadataProvider: metadataProvider)
        }

        let metadata = metadataProvider(newID)
        index = LibraryIndexMutator.renameNote(
            index: index,
            oldID: oldID,
            newID: newID,
            filesystemData: .init(
                title: metadata?.title,
                modified: metadata?.modified
            )
        )

        return true
    }

    private static func applyNoteModified(
        _ noteID: String,
        to index: inout LibraryIndex,
        metadataProvider: @escaping NoteMetadataProvider
    ) -> Bool {
        guard let existing = index.notes[noteID] else {
            return applyNoteAdded(noteID, to: &index, metadataProvider: metadataProvider)
        }

        guard let modified = metadataProvider(noteID)?.modified else {
            return false
        }

        let delta = abs(existing.modified.timeIntervalSince(modified))
        guard delta > 0.0005 else { return false }

        index = LibraryIndexMutator.updateNoteFromFilesystem(
            index: index,
            noteID: noteID,
            filesystemData: .init(modified: modified)
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
        metadataProvider: @escaping NoteMetadataProvider
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

            if index.notes[noteID] != nil {
                let metadata = metadataProvider(newNoteID)
                index = LibraryIndexMutator.renameNote(
                    index: index,
                    oldID: noteID,
                    newID: newNoteID,
                    filesystemData: .init(
                        title: metadata?.title,
                        modified: metadata?.modified
                    )
                )
                updatedNoteIDs.append(newNoteID)
            } else {
                _ = applyNoteAdded(newNoteID, to: &index, metadataProvider: metadataProvider)
                updatedNoteIDs.append(newNoteID)
            }
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

        if !missingNotes.isEmpty, !newNotes.isEmpty {
            var timestampPairs: [(oldID: String, newID: String)] = []

            for oldID in missingNotes {
                guard let oldNote = index.notes[oldID] else { continue }

                var candidate: String?
                for newID in newNotes {
                    guard let newSnapshot = snapshot.notes[newID] else { continue }
                    let delta = abs(oldNote.modified.timeIntervalSince(newSnapshot.modified))
                    guard delta <= threshold else { continue }

                    if candidate != nil {
                        candidate = nil
                        break
                    }
                    candidate = newID
                }

                if let candidate {
                    timestampPairs.append((oldID: oldID, newID: candidate))
                }
            }

            for pair in timestampPairs {
                missingNotes.remove(pair.oldID)
                newNotes.remove(pair.newID)
            }

            pairs.append(contentsOf: timestampPairs)
        }

        return pairs
    }

    private static func applyEventsSync(
        _ events: [LibraryFilesystemEvent],
        to index: LibraryIndex,
        metadataProvider: @escaping NoteMetadataProvider
    ) -> Result {
        var next = index
        var changed = false

        for event in events {
            if apply(event, to: &next, metadataProvider: metadataProvider) {
                changed = true
            }
        }

        if changed {
            next.lastUpdated = Date()
        }

        return Result(index: next, changed: changed)
    }
}
