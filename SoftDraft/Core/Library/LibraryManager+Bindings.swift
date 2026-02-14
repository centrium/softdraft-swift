//
//  LibraryManager+Bindings.swift
//  SoftDraft
//

import Foundation
import Combine

extension LibraryManager {

    func bind(selection: SelectionModel) {
        boundSearchIndex.map { scheduleSearchIndexRebuild($0) }
        self.selection = selection

        selection.$selectedCollectionID
            .removeDuplicates()
            .sink { [weak self] collectionID in
                self?.selectCollection(collectionID)
            }
            .store(in: &cancellables)

        // Persist last active collection when selection changes
        selection.$selectedCollectionID
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] collectionID in
                guard
                    let self,
                    let libraryURL = self.activeLibraryURL
                else { return }

                Task {
                    await LibraryMetaStore.updateLastActiveCollection(
                        libraryURL,
                        collectionId: collectionID
                    )
                }
            }
            .store(in: &cancellables)
    }

    func bind(searchIndex: SearchIndex) {
        print("✅ bind(searchIndex:) CALLED")

        self.boundSearchIndex = searchIndex

        // 🔑 CRITICAL: rebuild immediately with current state
        scheduleSearchIndexRebuild(searchIndex)

        $visibleNotes
            .sink { [weak self] _ in
                guard let self, let index = self.boundSearchIndex else { return }
                self.scheduleSearchIndexRebuild(index)
            }
            .store(in: &cancellables)
    }
}
