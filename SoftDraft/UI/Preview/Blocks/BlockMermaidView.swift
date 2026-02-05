//
//  BlockMermaidView.swift
//  SoftDraft
//

import SwiftUI

struct BlockMermaidView: View {
    let source: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal) {
                Text(source)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineSpacing(5)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("mermaid")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                )
                .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 14)
    }
}
