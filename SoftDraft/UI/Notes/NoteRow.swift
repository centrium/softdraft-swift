//
//  NoteRow.swift
//  SoftDraft
//
//  Created by Matt Adams on 21/01/2026.
//

import SwiftUI

struct NoteRow: View {

    let note: NoteSummary
    var isSelected: Bool = false
    var showsPinnedIndicator: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(Color.primary.opacity(0.84))

                Text(note.modifiedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary.opacity(0.86))
            }

            Spacer(minLength: 0)

            if showsPinnedIndicator {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.top, 3)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}
