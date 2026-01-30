//
//  UIState.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//


// UIState.swift

import Foundation
import Combine

@MainActor
final class UIState: ObservableObject {
    @Published var isZenModeEnabled: Bool = false
}
