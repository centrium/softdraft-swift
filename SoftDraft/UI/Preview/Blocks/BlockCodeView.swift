//
//  BlockCodeView.swift
//  SoftDraft
//
//  Created by Matt Adams on 04/02/2026.
//


import SwiftUI


struct BlockCodeView: View {
    let source: String
    let language: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal) {
                Text(source)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(16)
            }

            if let language, !language.isEmpty {
                Text(language.uppercased())
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
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 12)
    }
}
