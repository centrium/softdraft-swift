//
//  CollectionSelection.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import Foundation
import Combine

@MainActor
final class CollectionSelection: ObservableObject {
    @Published var activeCollection: String = "Inbox"
}
