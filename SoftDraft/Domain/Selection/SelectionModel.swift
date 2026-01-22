//
//  SelectionModel.swift
//  SoftDraft
//
//  Created by Matt Adams on 22/01/2026.
//

import Foundation
import Combine

@MainActor
final class SelectionModel: ObservableObject {
    @Published var selectedNoteID: String? = nil
}
