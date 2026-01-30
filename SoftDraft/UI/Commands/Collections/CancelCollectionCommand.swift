//
//  CancelCollectionCommand.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//

import SwiftUI

let cancelRenameCollectionCommand = AppCommand(
    id: "collection.rename.cancel",
    title: "Cancel Rename",
    shortcut: nil,
    isEnabled: { ctx in
        ctx.selection.pendingCollectionRename != nil
    },
    perform: { ctx in
        ctx.selection.cancelRenameCollection()
    }
)
