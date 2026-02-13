//
//  UIState.swift
//  SoftDraft
//
//  Created by Matt Adams on 30/01/2026.
//
import SwiftUI
import Combine

enum SidebarMode {
    case collections
    case tags
}

@MainActor
final class UIState: ObservableObject {

    /// Controls sidebar visibility in NavigationSplitView
    @Published var splitViewVisibility: NavigationSplitViewVisibility = .all
    @Published var sidebarMode: SidebarMode = .collections
    @Published var isPreviewModeEnabled: Bool = false
    @Published var isInsertingImage: Bool = false
    @Published var imageInsertionError: String? = nil
    @Published private(set) var notesListFocusRequestToken: UInt = 0

    /// Derived convenience for readability elsewhere
    var isZenModeEnabled: Bool {
        splitViewVisibility == .detailOnly
    }

    func requestNotesListFocus() {
        notesListFocusRequestToken &+= 1
    }
}
