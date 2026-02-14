//
//  LibraryManager+Search.swift
//  SoftDraft
//

import Foundation

extension LibraryManager {

    func scheduleSearchIndexRebuild(
        _ searchIndex: SearchIndex
    ) {
        guard !deferSearchIndexRebuild else {
            hasPendingSearchIndexRebuild = true
            return
        }

        rebuildSearchIndex(searchIndex)
    }

    func rebuildSearchIndex(_ searchIndex: SearchIndex) {
        guard
            let libraryURL = activeLibraryURL,
            let libraryIndex = libraryIndex
        else { return }

        let collectionsDir = collectionsDir
        let allNotes = libraryIndex.notes

        searchIndexRebuildTask?.cancel()

        searchIndexRebuildTask = Task.detached(priority: .utility) {

            var entries: [SearchIndexEntry] = []
            entries.reserveCapacity(allNotes.count)

            for (noteID, noteIndex) in allNotes {

                guard !Task.isCancelled else { return }

                // noteID format: "Collection/File.md"
                let parts = noteID.split(separator: "/", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let collectionID = String(parts[0])
                let filename = String(parts[1])

                let noteURL = libraryURL
                    .appendingPathComponent(collectionsDir)
                    .appendingPathComponent(collectionID)
                    .appendingPathComponent(filename)

                guard let markdown = try? String(contentsOf: noteURL, encoding: .utf8) else {
                    continue
                }

                entries.append(
                    SearchExtractor.extract(
                        noteID: noteID,
                        title: noteIndex.title,
                        markdown: markdown,
                        tags: noteIndex.tags
                    )
                )
            }

            guard !Task.isCancelled else { return }
            let builtEntries = entries

            await MainActor.run {
                guard !Task.isCancelled else { return }
                print("🔍 SEARCH INDEXED (GLOBAL):", builtEntries.count, "notes")
                searchIndex.replaceAll(builtEntries)
            }
        }
    }
}
