//
//  LibraryManager+Startup.swift
//  SoftDraft
//

import Foundation
import OSLog

private let libraryActivationLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.softdraft.app",
    category: "LibraryActivation"
)

extension LibraryManager {

    // MARK: - Startup

    func resolveInitialLibrarySync() {
        let config = AppConfigStore.loadSync()

        guard let storedURL = config.lastLibraryURL else {
            transitionToNoLibrary()
            return
        }
        let canonicalURL = storedURL.standardizedFileURL

        guard LibraryValidator.isLibraryRoot(canonicalURL) else {
            transitionToNoLibrary()
            return
        }

        transitionToLoadedLibrary(canonicalURL)
    }

    func resolveInitialLibrary() async {
        guard case .resolving = startupState else { return }
        let config = await AppConfigStore.load()

        guard let storedURL = config.lastLibraryURL else {
            transitionToNoLibrary()
            return
        }
        let canonicalURL = storedURL.standardizedFileURL

        // Validate the library still exists and is usable
        guard LibraryValidator.isLibraryRoot(canonicalURL) else {
            transitionToNoLibrary()
            return
        }

        transitionToLoadedLibrary(canonicalURL)
    }

    // MARK: - Library lifecycle

    func setActiveLibrary(_ url: URL) async {
        let canonicalURL = url.standardizedFileURL
        guard LibraryValidator.isLibraryRoot(canonicalURL) else {
            return
        }
        transitionToLoadedLibrary(canonicalURL)

        var config = await AppConfigStore.load()
        config.lastLibraryURL = canonicalURL
        await AppConfigStore.save(config)
    }

    func clearLibrary() async {
        transitionToNoLibrary()

        var config = await AppConfigStore.load()
        config.lastLibraryURL = nil
        await AppConfigStore.save(config)
    }

    private func transitionToLoadedLibrary(_ url: URL) {
        let canonicalURL = url.standardizedFileURL
        stopWatcher()
        activeLibraryURL = canonicalURL
        deferSearchIndexRebuild = true
        hasPendingSearchIndexRebuild = false
        searchIndexRebuildTask?.cancel()
        searchIndexRebuildTask = nil
        resetVisibleState()
        hasRunCatchUpReconciliation = false
        hasRunPinnedMigration = false

        // ✅ NEW: load or create library index
        loadOrCreateLibraryIndex(libraryURL: canonicalURL)

        applyIndexSnapshot(libraryURL: canonicalURL)

        startupState = .loaded(canonicalURL)

        startPostLaunchTasks(for: canonicalURL)
        libraryActivationLogger.info("Library activated successfully")
    }

    private func transitionToNoLibrary() {
        stopWatcher()
        activeLibraryURL = nil
        startupState = .noLibrary
        resetVisibleState()
        selection?.selectNote(nil)
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
