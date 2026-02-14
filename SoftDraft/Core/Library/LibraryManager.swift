//
//  LibraryManager.swift
//  SoftDraft
//
//  Created by Matt Adams on 20/01/2026.
//

// Core/Library/LibraryManager.swift

import Foundation
import Combine

@MainActor
final class LibraryManager: ObservableObject {

    enum StartupState {
        case resolving
        case noLibrary
        case loaded(URL)
    }

    let collectionsDir = "collections"

    @Published var activeLibraryURL: URL?
    @Published var startupState: StartupState = .resolving
    @Published var visibleNotes: [NoteSummary] = []
    @Published var visibleCollectionID: String?
    @Published var externalChangeTokens: [String: UUID] = [:]
    @Published var visibleCollections: [String] = []
    @Published var libraryIndex: LibraryIndex?
    @Published var visibleTag: String? = nil

    @Published var currentNoteText: String = ""

    var cancellables: Set<AnyCancellable> = []
    let mandatoryCollections: Set<String> = ["Inbox"]

    weak var selection: SelectionModel?
    var filesystemWatcher: LibraryFilesystemWatcher?
    var internalWriteDepth = 0
    var recentInternalWrites: [String: Date] = [:]
    let internalWriteCooldown: TimeInterval = 1.0
    // Tracks whether we still need to restore the persisted selection for this library.
    var needsInitialCollectionSelection = false
    var boundSearchIndex: SearchIndex?
    var isLibraryIndexDirty = false
    var hasRunCatchUpReconciliation = false
    var hasRunPinnedMigration = false
    var deferSearchIndexRebuild = false
    var hasPendingSearchIndexRebuild = false
    var searchIndexRebuildTask: Task<Void, Never>?
}
