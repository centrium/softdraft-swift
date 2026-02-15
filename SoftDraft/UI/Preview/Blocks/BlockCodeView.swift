//
//  BlockCodeView.swift
//  SoftDraft
//
//  Created by Matt Adams on 04/02/2026.
//


import SwiftUI
import AppKit


struct BlockCodeView: View {
    let source: String
    let language: String?
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
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(16)
            }

            if let language, !language.isEmpty {
                Text(language)
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
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(surfaceColor)
        )
        .overlay(alignment: .center) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTones.subtleStroke(for: colorScheme), lineWidth: 0.8)
        }
        .padding(.vertical, 12)
    }
}
