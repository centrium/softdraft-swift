//
//  LibraryIndexBuilder.swift
//  SoftDraft
//
//  Created by Matt Adams on 10/02/2026.
//

import Foundation

enum LibraryIndexBuilder {

    static let supportedVersion = 1

    static func isSupportedVersion(_ version: Int) -> Bool {
        version == supportedVersion
    }

    static func build(
        libraryURL: URL,
        existingLibraryID: String? = nil,
        existingIndex: LibraryIndex? = nil
    ) async -> LibraryIndex {
        let existingPinnedByNoteID = existingIndex?.notes.reduce(
            into: [String: Bool]()
        ) { partialResult, pair in
            partialResult[pair.key] = pair.value.pinned
        } ?? [:]

        return await Task.detached(priority: .utility) {
            buildSync(
                libraryURL: libraryURL,
                existingLibraryID: existingLibraryID,
                existingPinnedByNoteID: existingPinnedByNoteID
            )
        }.value
    }

    static func extractLibraryID(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let json = object as? [String: Any]
        else {
            return nil
        }

        return json["libraryID"] as? String
    }

    private static func buildSync(
        libraryURL: URL,
        existingLibraryID: String?,
        existingPinnedByNoteID: [String: Bool]
    ) -> LibraryIndex {
        let collectionsURL = libraryURL
            .appendingPathComponent(CollectionStore.collectionsDir)

        var collections: [String: CollectionIndex] = [:]
        var notes: [String: NoteIndex] = [:]
        var tagFrequencies: [String: Int] = [:]

        let collectionURLs = (try? FileManager.default.contentsOfDirectory(
            at: collectionsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for collectionURL in collectionURLs {
            let values = try? collectionURL.resourceValues(
                forKeys: [.isDirectoryKey]
            )
            guard values?.isDirectory == true else { continue }

            let collectionID = collectionURL.lastPathComponent
            collections[collectionID] = CollectionIndex(
                id: collectionID,
                noteIDs: []
            )

            let noteURLs = (try? FileManager.default.contentsOfDirectory(
                at: collectionURL,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .contentModificationDateKey
                ],
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
                let markdown = (try? String(contentsOf: noteURL, encoding: .utf8)) ?? ""
                let title = MarkdownTitle.displayTitle(
                    from: markdown,
                    fallbackFilename: filename
                )
                let parsedTags = TagParser.parseTags(from: markdown)
                let tags = parsedTags.sorted()
                let existingPinned = existingPinnedByNoteID[noteID] ?? false

                for tag in parsedTags {
                    tagFrequencies[tag, default: 0] += 1
                }

                notes[noteID] = NoteIndex(
                    id: noteID,
                    path: noteID,
                    title: title,
                    modified: modified,
                    pinned: existingPinned,
                    tags: tags
                )

                collections[collectionID]?.noteIDs.append(noteID)
            }

            if var entry = collections[collectionID] {
                entry.noteIDs.sort()
                collections[collectionID] = entry
            }
        }

        return LibraryIndex(
            version: supportedVersion,
            libraryID: existingLibraryID ?? UUID().uuidString,
            lastUpdated: Date(),
            collections: collections,
            notes: notes,
            tagFrequencies: tagFrequencies
        )
    }
}
