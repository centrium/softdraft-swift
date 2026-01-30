//
//  SelectionModel.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import Foundation
import Combine

struct PendingMove {
    let noteID: String
    let destinationCollection: String?
}

struct PendingCollectionRename {
    let originalID: String
}

@MainActor
final class SelectionModel: ObservableObject {

    @Published var selectedCollectionID: String? = nil
    @Published var selectedNoteID: String? = nil
    @Published var pendingCollectionRename: PendingCollectionRename? = nil
    @Published var collectionRenameDraft: String = ""

    @Published var pendingMove: PendingMove? = nil

    func selectCollection(_ id: String?) {
        selectedCollectionID = id
        selectedNoteID = nil
        pendingMove = nil
    }

    func selectNote(_ id: String?) {
        selectedNoteID = id
    }

    func clearNoteSelection() {
        selectedNoteID = nil
        pendingMove = nil
    }
    
    func beginRenameCollection(_ id: String) {
        pendingCollectionRename = PendingCollectionRename(originalID: id)
        collectionRenameDraft = id
    }

    func cancelRenameCollection() {
        pendingCollectionRename = nil
        collectionRenameDraft = ""
    }
}
