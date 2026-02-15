//
//  BlockMathView.swift
//  SoftDraft
//
//  Created by Matt Adams on 04/02/2026.
//


import SwiftUI
import AppKit

struct BlockMathView: View {
    let source: String
    @Environment(\.colorScheme) private var colorScheme

    private var surfaceColor: Color {
        AppTones.raisedSurface(for: colorScheme)
    }

    var body: some View {
        ScrollView(.horizontal) {
            Text(source)
                .font(AppTypography.monospacedBody)
                .foregroundStyle(Color.primary)
                .lineSpacing(6)
                .lineLimit(nil)
                .fixedSize(horizontal: true, vertical: true)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .overlay(alignment: .topTrailing) {
            Text("Equation")
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
