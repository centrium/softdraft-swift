//
//  BlockMermaidView.swift
//  SoftDraft
//

import SwiftUI
import AppKit

struct BlockMermaidView: View {
    let source: String
    @Environment(\.colorScheme) private var colorScheme

    private var surfaceColor: Color {
        AppTones.raisedSurface(for: colorScheme)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal) {
                Text(source)
                    .font(AppTypography.monospacedBody)
                    .foregroundStyle(Color.primary)
                    .lineSpacing(5)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Mermaid")
                .font(AppTypography.caption)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTones.badgeSurface(for: colorScheme))
                )
                .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(surfaceColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTones.subtleStroke(for: colorScheme), lineWidth: 0.8)
        }
        .padding(.vertical, 16)
    }
}
