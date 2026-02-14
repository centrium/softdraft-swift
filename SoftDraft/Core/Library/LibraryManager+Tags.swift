//
//  LibraryManager+Tags.swift
//  SoftDraft
//

import Foundation

extension LibraryManager {

    struct TagItem: Identifiable {
    let id: String
    let count: Int
    }

    var allTagsSorted: [TagItem] {
        guard let index = libraryIndex else { return [] }

        return index.tagFrequencies
            .map { TagItem(id: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.id < $1.id
                }
                return $0.count > $1.count
            }
    }

    // MARK: - Tags

    @MainActor
    func selectTag(_ tag: String) {
        visibleTag = tag
        visibleCollectionID = nil
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
    }

    @MainActor
    func clearTagSelection() {
        visibleTag = nil
        visibleCollectionID = selection?.selectedCollectionID
        updateVisibleNotes()
        validateSelectionInVisibleNotes()
    }

    @MainActor
    func enterTagMode() {
        visibleTag = nil
        visibleCollectionID = nil
        selection?.selectNote(nil)
        updateVisibleNotes()
    }
}
