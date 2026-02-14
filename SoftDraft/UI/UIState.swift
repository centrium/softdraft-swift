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

enum FocusRegion: CaseIterable {
    case sidebar
    case notesList
    case editor
}

@MainActor
final class UIState: ObservableObject {

    /// Controls sidebar visibility in NavigationSplitView
    @Published var splitViewVisibility: NavigationSplitViewVisibility = .all
    @Published var sidebarMode: SidebarMode = .collections
    @Published var isCollectionsListExpanded: Bool = false
    @Published var activeFocusRegion: FocusRegion = .sidebar
    @Published var isPreviewModeEnabled: Bool = false
    @Published var isInsertingImage: Bool = false
    @Published var imageInsertionError: String? = nil
    @Published var noteStateFilter: NoteState? = nil
    @Published private(set) var focusRequestToken: UInt = 0
    @Published private(set) var requestedFocusRegion: FocusRegion = .sidebar

    /// Derived convenience for readability elsewhere
    var isZenModeEnabled: Bool {
        splitViewVisibility == .detailOnly
    }

    func requestNotesListFocus() {
        requestFocus(.notesList)
    }

    func requestFocus(_ region: FocusRegion) {
        requestedFocusRegion = region
        focusRequestToken &+= 1
    }
}
