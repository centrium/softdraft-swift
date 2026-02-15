//
//  DebugFallbackBlockView.swift
//  SoftDraft
//
//  Created by Matt Adams on 02/02/2026.
//

import SwiftUI

struct DebugFallbackBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        Text("[Unsupported block: \(String(describing: block))]")
            .font(AppTypography.monospacedCaption)
            .foregroundStyle(.secondary)
    }
}
