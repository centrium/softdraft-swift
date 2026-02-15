//
//  StartupPlaceholderView.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct StartupPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Opening Softdraft…")
                .font(AppTypography.secondaryBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
