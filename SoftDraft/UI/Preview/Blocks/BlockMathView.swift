//
//  BlockMathView.swift
//  SoftDraft
//
//  Created by Matt Adams on 04/02/2026.
//


import SwiftUI

struct BlockMathView: View {
    let source: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(source)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .lineSpacing(6)
                .lineLimit(nil)
                .fixedSize(horizontal: true, vertical: true)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .overlay(alignment: .topTrailing) {
            Text("Equation")
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
        .padding(.vertical, 16)
    }
}
