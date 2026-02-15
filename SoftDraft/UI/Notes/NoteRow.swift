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
    var accentColor: Color = .clear
    var accentOpacity: Double = SidebarAccentPalette.stripOpacity

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(accentColor.opacity(accentOpacity))
                .frame(width: SidebarAccentPalette.stripWidth)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(Color.primary.opacity(recencyTitleOpacity))

                Text(relativeRecencyText)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
                    .foregroundStyle(.secondary.opacity(recencySubtitleOpacity))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .overlay(alignment: .trailing) {
            VStack(spacing: 4) {
                Circle()
                    .fill(stateIndicatorColor)
                    .frame(width: 8, height: 8)

                if showsPinnedIndicator {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .padding(.trailing, 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var relativeRecencyText: String {
        Self.relativeFormatter.localizedString(for: note.modifiedAt, relativeTo: Date())
    }

    private var recencySubtitleOpacity: Double {
        max(0.48, recencyTitleOpacity - 0.20)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private var recencyTitleOpacity: Double {
        let age = max(0, Date().timeIntervalSince(note.modifiedAt))
        let ageHours = age / 3600

        let base: Double
        if ageHours <= 24 {
            base = 0.90
        } else if ageHours <= 72 {
            base = 0.87
        } else if ageHours <= 168 {
            base = 0.84
        } else if ageHours <= 720 {
            base = 0.80
        } else {
            base = 0.76
        }

        return isSelected ? min(base + 0.04, 0.92) : base
    }

    private var stateIndicatorColor: Color {
        switch note.state {
        case .drafting:
            return Color.primary.opacity(0.25)
        case .refining:
            return Color.orange.opacity(0.35)
        case .finished:
            return Color.green.opacity(0.35)
        }
    }
}
