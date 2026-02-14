//
//  LibraryManager+Startup.swift
//  SoftDraft
//

import Foundation

extension LibraryManager {

    // MARK: - Startup

    func resolveInitialLibrarySync() {
        let config = AppConfigStore.loadSync()

        guard let url = config.lastLibraryURL else {
            transitionToNoLibrary()
            return
        }

        guard LibraryValidator.isLibraryRoot(url) else {
            transitionToNoLibrary()
            return
        }

        transitionToLoadedLibrary(url)
    }

    func resolveInitialLibrary() async {
        guard case .resolving = startupState else { return }
        let config = await AppConfigStore.load()

        guard let url = config.lastLibraryURL else {
            transitionToNoLibrary()
            return
        }

        // Validate the library still exists and is usable
        guard LibraryValidator.isLibraryRoot(url) else {
            transitionToNoLibrary()
            return
        }

        transitionToLoadedLibrary(url)
    }

    // MARK: - Library lifecycle

    func setActiveLibrary(_ url: URL) async {
        transitionToLoadedLibrary(url)

        var config = await AppConfigStore.load()
        config.lastLibraryURL = url
        await AppConfigStore.save(config)
    }

    func clearLibrary() async {
        transitionToNoLibrary()

        var config = await AppConfigStore.load()
        config.lastLibraryURL = nil
        await AppConfigStore.save(config)
    }

    private func transitionToLoadedLibrary(_ url: URL) {
        stopWatcher()
        activeLibraryURL = url
        deferSearchIndexRebuild = true
        hasPendingSearchIndexRebuild = false
        searchIndexRebuildTask?.cancel()
        searchIndexRebuildTask = nil
        resetVisibleState()
        hasRunCatchUpReconciliation = false
        hasRunPinnedMigration = false

        // ✅ NEW: load or create library index
        loadOrCreateLibraryIndex(libraryURL: url)

        applyIndexSnapshot(libraryURL: url)

        startupState = .loaded(url)

        startPostLaunchTasks(for: url)
    }

    private func transitionToNoLibrary() {
        stopWatcher()
        activeLibraryURL = nil
        startupState = .noLibrary
        resetVisibleState()
        selection?.selectedNoteID = nil
        deferSearchIndexRebuild = false
        hasPendingSearchIndexRebuild = false
        searchIndexRebuildTask?.cancel()
        searchIndexRebuildTask = nil
    }

    private func resetVisibleState() {
        visibleTag = nil
        visibleCollectionID = nil
        currentNoteText = ""
        needsInitialCollectionSelection = true
        selection?.selectCollection(nil)
        updateVisibleNotes()
    }

    private func startPostLaunchTasks(for url: URL) {
        Task { [weak self] in
            await Task.yield()
            await self?.runPostLaunchTasks(for: url)
        }
    }

    @MainActor
    private func runPostLaunchTasks(for url: URL) async {
        guard activeLibraryURL == url else { return }

        startWatcher(for: url)
        scheduleCatchUpReconciliation(libraryURL: url)

        deferSearchIndexRebuild = false
        if hasPendingSearchIndexRebuild,
           let searchIndex = boundSearchIndex {
            hasPendingSearchIndexRebuild = false
            rebuildSearchIndex(searchIndex)
        }

        await ensureMandatoryCollectionsExist(libraryURL: url)
    }
}
