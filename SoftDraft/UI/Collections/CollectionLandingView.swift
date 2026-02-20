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
    @State private var headlineText: String = "Inbox is open."
    @State private var previousHeadlineTemplate: String? = nil
    @State private var headlineVisible = false

    var body: some View {
        ZStack {
            inkyBackground
            landingCopy
        }
        .onAppear {
            refreshHeadline(for: collectionName, animated: true)
        }
        .onChange(of: collectionName) { _, newValue in
            refreshHeadline(for: newValue, animated: true)
        }
    }

    private var inkyBackground: some View {
        ZStack {
            baseSurfaceColor
            Rectangle()
                .fill(layerSurfaceColor)
                .blendMode(colorScheme == .dark ? .screen : .multiply)
                .opacity(colorScheme == .dark ? 0.06 : 0.035)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var landingCopy: some View {
        GeometryReader { proxy in
            VStack(spacing: 16) {
                Text(collectionLabel.uppercased())
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .tracking(1.85)
                    .foregroundStyle(contextInkColor.opacity(0.78))
                    .textSelection(.disabled)

                Text(headlineText)
                    .font(.system(size: 33, weight: .semibold, design: .serif))
                    .lineSpacing(7)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(primaryInkColor)
                    .frame(maxWidth: 560)
                    .opacity(headlineVisible ? 1.0 : 0.0)
                    .textSelection(.disabled)

                Text(secondaryLine)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .tracking(0.25)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryInkColor.opacity(0.90))
                    .frame(maxWidth: 500)
                    .padding(.top, 5)
                    .textSelection(.disabled)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .offset(y: -(proxy.size.height * 0.06))
        }
    }

    private var collectionLabel: String {
        collectionName.localizedCaseInsensitiveCompare("Inbox") == .orderedSame
            ? "Inbox"
            : collectionName
    }

    private var secondaryLine: String {
        if isCollectionEmpty {
            return "Quiet, deliberate, and ready."
        }
        return metadataLine
    }

    private var baseSurfaceColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.10, green: 0.105, blue: 0.11)
        }
        return Color(red: 0.962, green: 0.947, blue: 0.923)
    }

    private var layerSurfaceColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.20, green: 0.205, blue: 0.212)
        }
        return Color(red: 0.90, green: 0.875, blue: 0.84)
    }

    private var primaryInkColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.84, green: 0.82, blue: 0.79)
        }
        return Color(red: 0.17, green: 0.145, blue: 0.12)
    }

    private var secondaryInkColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.66, green: 0.63, blue: 0.59)
        }
        return Color(red: 0.34, green: 0.29, blue: 0.24)
    }

    private var contextInkColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.58, green: 0.55, blue: 0.51)
        }
        return Color(red: 0.42, green: 0.35, blue: 0.28)
    }

    private var isCollectionEmpty: Bool {
        (summary?.noteCount ?? 0) == 0
    }

    private func refreshHeadline(for name: String, animated: Bool) {
        let template = pickHeadlineTemplate()
        previousHeadlineTemplate = template
        headlineText = template.replacingOccurrences(of: "{Collection}", with: label(for: name))

        guard animated else {
            headlineVisible = true
            return
        }

        headlineVisible = false
        withAnimation(.easeOut(duration: 0.52)) {
            headlineVisible = true
        }
    }

    private func pickHeadlineTemplate() -> String {
        let templates: [String] = isCollectionEmpty
            ? Self.emptyHeadlineTemplates
            : Self.populatedHeadlineTemplates

        let choices: [String]
        if let previousHeadlineTemplate, templates.count > 1 {
            let filtered = templates.filter { $0 != previousHeadlineTemplate }
            choices = filtered.isEmpty ? templates : filtered
        } else {
            choices = templates
        }

        return choices.randomElement() ?? templates[0]
    }

    private func label(for name: String) -> String {
        name.localizedCaseInsensitiveCompare("Inbox") == .orderedSame ? "Inbox" : name
    }

    private static let emptyHeadlineTemplates: [String] = [
        "{Collection} is open.",
        "Everything in {Collection}, held quietly.",
        "Nothing pressing in {Collection}.",
        "{Collection} keeps its place.",
        "{Collection}, ready when you are.",
    ]

    private static let populatedHeadlineTemplates: [String] = [
        "{Collection} is open.",
        "Everything in {Collection}, held quietly.",
        "{Collection}, just as you left it.",
        "{Collection} keeps its place.",
        "Notes in {Collection}, kept lightly.",
        "{Collection}, ready when you are.",
    ]

    private var metadataLine: String {
        let countText = noteCountDescriptor(for: summary?.noteCount)
        let updatedText = lastUpdatedText

        switch (countText.isEmpty, updatedText.isEmpty) {
        case (true, true):
            return "Quiet for now"
        case (false, true):
            return countText
        case (true, false):
            return updatedText
        default:
            return "\(countText) · \(updatedText)"
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

        return "Updated "
            + lastUpdated.formatted(
                Date.FormatStyle()
                    .month(.abbreviated)
                    .day(.defaultDigits)
                    .hour(.defaultDigits(amPM: .abbreviated))
                    .minute()
            )
    }
}
