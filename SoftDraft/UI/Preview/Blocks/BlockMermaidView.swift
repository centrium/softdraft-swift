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
        Color(nsColor: .controlBackgroundColor)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal) {
                Text(source)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Color.primary)
                    .lineSpacing(5)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("mermaid")
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
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(surfaceColor)
        )
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            }
        }
        .padding(.vertical, 14)
    }
}
