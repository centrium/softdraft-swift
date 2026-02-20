//
//  LibraryManager+Filesystem.swift
//  SoftDraft
//

import Foundation
import OSLog

private let libraryWatcherLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.softdraft.app",
    category: "LibraryWatcher"
)

extension LibraryManager {

    // MARK: - Filesystem reconciliation

    func reconcileSavedNoteImmediately(
        noteID: String,
        libraryURL: URL
    ) async {
        guard activeLibraryURL == libraryURL else { return }
        guard let index = libraryIndex else { return }

        let result = await LibraryIndexReconciler.applyEvents(
            [.modified(noteID: noteID)],
            to: index,
            libraryURL: libraryURL
        )

        guard activeLibraryURL == libraryURL else { return }
        guard result.changed else { return }
        libraryIndex = result.index
        persistLibraryIndex(libraryURL: libraryURL)
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
        signalExternalChange(for: noteID)
    }

    func reconcile(_ events: [LibraryFilesystemEvent]) async {
        guard
            let libraryURL = activeLibraryURL,
            !isPerformingInternalWrite
        else { return }

        cleanupInternalWrites()

        var reconciliationEvents: [LibraryFilesystemEvent] = []
        reconciliationEvents.reserveCapacity(events.count)

        for event in events {
            switch event {
            case .added(let noteID):
                guard !shouldIgnore(noteID: noteID) else { continue }
                reconciliationEvents.append(event)

            case .modified(let noteID):
                guard !shouldIgnore(noteID: noteID) else { continue }
                reconciliationEvents.append(event)

            case let .renamed(from, to):
                guard !shouldIgnore(noteID: from), !shouldIgnore(noteID: to) else { continue }
                reconciliationEvents.append(event)
                if selection?.selectedNoteID == from {
                    selection?.selectNote(to)
                    signalExternalChange(for: to)
                }

            case .deleted(let noteID):
                guard !shouldIgnore(noteID: noteID) else { continue }
                reconciliationEvents.append(event)
                if selection?.selectedNoteID == noteID {
                    selection?.selectNote(nil)
                }

            case let .collectionRenamed(from, to):
                reconciliationEvents.append(event)
                if selection?.selectedCollectionID == from {
                    selection?.selectCollection(to)
                }

            case let .collectionDeleted(collectionID):
                reconciliationEvents.append(event)
                if selection?.selectedCollectionID == collectionID {
                    selection?.selectCollection(nil)
                }

            case .collectionAdded:
                reconciliationEvents.append(event)
            }
        }

        guard
            !reconciliationEvents.isEmpty,
            let index = libraryIndex
        else { return }

        let result = await LibraryIndexReconciler.applyEvents(
            reconciliationEvents,
            to: index,
            libraryURL: libraryURL
        )

        guard activeLibraryURL == libraryURL else { return }
        guard result.changed else { return }
        libraryIndex = result.index
        persistLibraryIndex(libraryURL: libraryURL)
        refreshVisibleStateFromIndex(libraryURL: libraryURL)
        validateSelectionInVisibleNotes()
    }

    @MainActor
    func replaceNoteID(oldID: String, newID: String) {
        updateLibraryIndexAfterRenameNote(
            oldID: oldID,
            newID: newID
        )

        if let libraryURL = activeLibraryURL {
            persistLibraryIndex(libraryURL: libraryURL)
        }

        if selection?.selectedNoteID == oldID {
            selection?.selectNote(newID)
        }

        updateVisibleNotes()
        validateSelectionInVisibleNotes()
        signalExternalChange(for: newID)
    }

    @MainActor
    func refreshNoteID(_ noteID: String) {
        guard libraryIndex?.notes[noteID] != nil else { return }
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
        signalExternalChange(for: noteID)
    }

    func startWatcher(for url: URL) {
        let canonicalRoot = url.standardizedFileURL
        let watcher = LibraryFilesystemWatcher(libraryURL: canonicalRoot) { [weak self] events in
            guard let self else { return }
            Task { @MainActor in
                guard !self.isPerformingInternalWrite else { return }
                await self.reconcile(events)
            }
        }
        watcher.start()
        filesystemWatcher = watcher
        libraryWatcherLogger.info(
            "Watcher attached to canonical root: \(canonicalRoot.path, privacy: .public)"
        )
    }

    func stopWatcher() {
        filesystemWatcher?.stop()
        filesystemWatcher = nil
    }

    func scheduleCatchUpReconciliation(libraryURL: URL) {
        guard !hasRunCatchUpReconciliation else { return }
        hasRunCatchUpReconciliation = true

        Task { [weak self] in
            guard let self else { return }
            await Task.yield()

            guard self.activeLibraryURL == libraryURL else { return }
            guard let index = self.libraryIndex else { return }
            let baselineLastUpdated = index.lastUpdated

            let result = await LibraryIndexReconciler.reconcileAgainstFilesystem(
                libraryURL: libraryURL,
                index: index
            )

            guard self.activeLibraryURL == libraryURL else { return }
            guard self.libraryIndex?.lastUpdated == baselineLastUpdated else { return }
            guard result.changed else { return }
            self.libraryIndex = result.index
            self.persistLibraryIndex(libraryURL: libraryURL)
            self.refreshVisibleStateFromIndex(libraryURL: libraryURL)
            if let searchIndex = self.boundSearchIndex {
                self.rebuildSearchIndex(searchIndex)
            }
            await self.migratePinnedStateIfNeeded(libraryURL: libraryURL)
        }
    }

    private func signalExternalChange(for noteID: String) {
        externalChangeTokens[noteID] = UUID()
    }
}
