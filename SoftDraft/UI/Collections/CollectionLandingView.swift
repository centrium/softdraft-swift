//
//  CollectionLandingView.swift
//  SoftDraft
//

import SwiftUI

struct CollectionLandingSummary: Equatable {
    let noteCount: Int
    let lastUpdated: Date?
}

struct CollectionLandingView: View {

    let collectionName: String
    let summary: CollectionLandingSummary?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundImage

            promptText

            VStack {
                Spacer(minLength: 0)
                contentCard
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 48)
        }
    }

    private var backgroundImage: some View {
        Image("CollectionLandingBackground")
            .resizable()
            .scaledToFill()
            .saturation(1.1)
            .contrast(colorScheme == .dark ? 0.9 : 1.05)
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(colorScheme == .dark ? 0.65 : 0.45),
                        .black.opacity(colorScheme == .dark ? 0.2 : 0.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .blendMode(.multiply)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var contentCard: some View {
        VStack(spacing: 10) {
            Text(collectionName)
                .font(.system(size: 34, weight: .semibold, design: .default))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .textSelection(.disabled)

            Text(metadataLine)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .textSelection(.disabled)
        }
        .frame(maxWidth: 460)
        .padding(.vertical, 30)
        .padding(.horizontal, 36)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.9 : 0.95)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 24, y: 14)
        .frame(maxWidth: .infinity)
    }

    private var promptText: some View {
        Text(promptLine)
            .font(.system(size: 20, weight: .medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .foregroundStyle(.white.opacity(colorScheme == .dark ? 0.95 : 0.9))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            .allowsHitTesting(false)
    }

    private var promptLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "What are you going to write this morning?"
        case 12..<17:
            return "What are you going to write this afternoon?"
        case 17..<22:
            return "What are you going to write this evening?"
        default:
            return "What are you going to write today?"
        }
    }

    private var metadataLine: String {
        let countText = noteCountDescriptor(for: summary?.noteCount)
        let updatedText = lastUpdatedText

        switch (countText.isEmpty, updatedText.isEmpty) {
        case (true, true):
            return "Select a note when you’re ready to continue"
        case (false, true):
            return countText
        case (true, false):
            return updatedText
        default:
            return "\(countText) • \(updatedText)"
        }
    }

    private func noteCountDescriptor(for count: Int?) -> String {
        guard let count else { return "" }
        switch count {
        case 0:
            return "No notes yet"
        case 1:
            return "1 note"
        default:
            return "\(count) notes"
        }
    }

    private var lastUpdatedText: String {
        guard let lastUpdated = summary?.lastUpdated else { return "" }

        return "Last updated "
            + lastUpdated.formatted(
                Date.FormatStyle()
                    .month(.abbreviated)
                    .day(.defaultDigits)
                    .hour(.defaultDigits(amPM: .abbreviated))
                    .minute()
            )
    }
}
