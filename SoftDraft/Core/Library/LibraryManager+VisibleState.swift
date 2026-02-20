//
//  LibraryManager+VisibleState.swift
//  SoftDraft
//

import Foundation

extension LibraryManager {

    private func summaryFromIndex(
        noteID: String,
        note: NoteIndex,
        fallbackCollection: String
    ) -> NoteSummary {
        let parts = noteID.split(separator: "/", maxSplits: 1)
        let collectionID = parts.first.map(String.init) ?? fallbackCollection
        let filename = parts.count > 1 ? String(parts[1]) : (noteID as NSString).lastPathComponent
        let name = filename.replacingOccurrences(
            of: ".md",
            with: "",
            options: .caseInsensitive
        )
        let friendlyFromFilename = MarkdownTitle.displayTitle(fromFilename: filename)
        let title: String
        if note.title.isEmpty {
            title = friendlyFromFilename
        } else if note.title == name {
            title = friendlyFromFilename
        } else {
            title = note.title
        }

        return NoteSummary(
            id: note.id,
            name: name,
            title: title,
            relativeDir: collectionID,
            modifiedAt: note.modified,
            pinned: note.pinned,
            state: note.state
        )
    }

    private func sortNotes(_ notes: [NoteSummary]) -> [NoteSummary] {
        notes.sorted { lhs, rhs in
            if lhs.modifiedAt == rhs.modifiedAt {
                return lhs.id < rhs.id
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }
    }

    func collectionID(for noteID: String) -> String {
        noteID.split(separator: "/").first.map(String.init) ?? "Inbox"
    }

    // MARK: - Helpers

    func validateSelectionInVisibleNotes() {
        guard let selectedNoteID = selection?.selectedNoteID else { return }
        guard visibleNotes.contains(where: { $0.id == selectedNoteID }) else {
            selection?.selectNote(nil)
            return
        }
    }

    func updateVisibleNotes(selectedCollectionID: String? = nil) {
        guard let index = libraryIndex else {
            visibleNotes = []
            print("🔎 Mode:", visibleTag ?? selectedCollectionID ?? selection?.selectedCollectionID ?? "none")
            print("📄 Visible notes:", visibleNotes.count)
            return
        }

        if let visibleTag {
            visibleCollectionID = nil

            let summaries = index.notes.values
                .filter { $0.tags.contains(visibleTag) }
                .map { note in
                    summaryFromIndex(
                        noteID: note.id,
                        note: note,
                        fallbackCollection: collectionID(for: note.id)
                    )
                }

            visibleNotes = sortNotes(summaries)
        } else if let effectiveCollectionID = selectedCollectionID ?? selection?.selectedCollectionID {
            visibleCollectionID = effectiveCollectionID

            var candidateNoteIDs = Set(index.collections[effectiveCollectionID]?.noteIDs ?? [])
            let prefixedNoteIDs = index.notes.keys.filter {
                collectionID(for: $0) == effectiveCollectionID
            }
            candidateNoteIDs.formUnion(prefixedNoteIDs)

            let summaries = candidateNoteIDs.compactMap { noteID -> NoteSummary? in
                guard let note = index.notes[noteID] else { return nil }
                return summaryFromIndex(
                    noteID: noteID,
                    note: note,
                    fallbackCollection: effectiveCollectionID
                )
            }

            visibleNotes = sortNotes(summaries)
        } else {
            visibleCollectionID = selectedCollectionID
            visibleNotes = []
        }

        print("🔎 Mode:", visibleTag ?? selectedCollectionID ?? selection?.selectedCollectionID ?? "none")
        print("📄 Visible notes:", visibleNotes.count)
    }

    func applyIndexSnapshot(libraryURL: URL) {
        guard let index = libraryIndex else {
            visibleCollections = []
            visibleCollectionID = nil
            updateVisibleNotes()
            return
        }

        visibleCollections = index.collections.keys.sorted()
        restoreInitialCollectionSelection(
            libraryURL: libraryURL,
            available: visibleCollections
        )

        if let selected = selection?.selectedCollectionID {
            selectCollection(selected)
        } else {
            visibleCollectionID = nil
            updateVisibleNotes()
            validateSelectionInVisibleNotes()
        }
        // Notes are opened by intent, never by default.
        // Startup restores collection context only and keeps note selection empty.
    }

    private func restoreInitialCollectionSelection(
        libraryURL: URL,
        available: [String]
    ) {
        guard let selection else { return }

        if let current = selection.selectedCollectionID,
           available.contains(current) {
            needsInitialCollectionSelection = false
            return
        }

        guard !available.isEmpty else {
            needsInitialCollectionSelection = false
            selection.selectCollection(nil)
            return
        }

        if let meta = try? LibraryMetaStore.load(libraryURL),
           let preferred = meta.lastActiveCollectionId,
           available.contains(preferred) {
            needsInitialCollectionSelection = false
            selection.selectCollection(preferred)
            return
        }

        needsInitialCollectionSelection = false

        if let fallback = fallbackCollection(from: available) {
            selection.selectCollection(fallback)
        } else {
            selection.selectCollection(nil)
        }
    }

    func refreshVisibleStateFromIndex(libraryURL: URL) {
        guard let index = libraryIndex else { return }

        visibleCollections = index.collections.keys.sorted()
        ensureCollectionSelection(libraryURL: libraryURL)

        if let selected = selection?.selectedCollectionID {
            if visibleTag == nil {
                visibleCollectionID = selected
            }
            updateVisibleNotes()
            validateSelectionInVisibleNotes()
        } else {
            visibleCollectionID = nil
            updateVisibleNotes()
            validateSelectionInVisibleNotes()
        }
    }

}
