//
//  SidebarAccentPalette.swift
//  SoftDraft
//

import SwiftUI

enum SidebarAccentPalette {
    static let collections = Color(red: 0.34, green: 0.49, blue: 0.39)
    static let tags        = Color(red: 0.50, green: 0.39, blue: 0.38)

    static let stripWidth: CGFloat = 3.0

    // Base presence: confident but quiet
    static let stripOpacity: Double = 0.46

    // Selected: slight lift, not a jump
    static let selectedStripOpacity: Double = 0.56

    // Pinned: anchored, not highlighted
    static let pinnedStripOpacity: Double = 0.62
}

extension SidebarMode {
    var sidebarAccentColor: Color {
        switch self {
        case .collections:
            return SidebarAccentPalette.collections
        case .tags:
            return SidebarAccentPalette.tags
        }
    }
}
