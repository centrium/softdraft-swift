//
//  ThematicBreakView.swift
//  SoftDraft
//
//  Created by Matt Adams on 04/02/2026.
//

import SwiftUI
import AppKit

struct ThematicBreakView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(ruleColor)
            .frame(height: 1)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
    }

    private var ruleColor: Color {
        let base = Color(nsColor: .separatorColor)
        return base.opacity(colorScheme == .dark ? 0.8 : 1)
    }
}
