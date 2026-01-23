//
//  LibraryManager+collections.swift
//  SoftDraft
//
//  Created by Matt Adams on 23/01/2026.
//

extension LibraryManager: CollectionsSnapshot {
    func allCollections() -> [String] {
        guard let libraryURL = currentLibraryURL else {
            return []
        }

        return (try? CollectionStore.list(libraryURL: libraryURL)) ?? []
    }
}
