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
}

@MainActor
final class SelectionModel: ObservableObject {
    @Published var selectedNoteID: String? = nil
    
    @Published var pendingMove: PendingMove? = nil
}
