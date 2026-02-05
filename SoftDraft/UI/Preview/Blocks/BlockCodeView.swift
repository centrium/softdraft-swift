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
        Color(nsColor: .controlBackgroundColor)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal) {
                Text(source)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color.primary)
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(16)
            }

            if let language, !language.isEmpty {
                Text(language.uppercased())
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .separatorColor).opacity(0.4))
                    )
                    .padding(8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(surfaceColor)
        )
        .overlay(alignment: .center) {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            }
        }
        .padding(.vertical, 12)
    }
}
