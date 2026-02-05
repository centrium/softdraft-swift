//
//  ThematicBreakView.swift
//  SoftDraft
//
//  Created by Matt Adams on 04/02/2026.
//

import SwiftUI

struct ThematicBreakView: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.25))
            .frame(height: 1)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
    }
}
