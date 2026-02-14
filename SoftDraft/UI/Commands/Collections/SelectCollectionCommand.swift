//
//  SelectCollectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 14/02/2026.
//

import SwiftUI

let selectCollectionCommand = AppCommand(
    id: "collection.select",
    title: "Select Collection",
    shortcut: nil,
    isEnabled: { _, arguments in
        arguments.collectionID != nil
    },
    perform: { ctx, arguments in
        guard let collectionID = arguments.collectionID else { return }
        ctx.selection.selectCollection(collectionID)
        ctx.uiState.requestFocus(.sidebar)
    }
)
