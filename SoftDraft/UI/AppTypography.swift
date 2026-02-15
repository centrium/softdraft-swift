//
//  AppTypography.swift
//  SoftDraft
//

import SwiftUI

enum AppTypography {
    static let primaryTitle = Font.system(size: 24, weight: .semibold, design: .default)
    static let secondaryHeading = Font.system(size: 20, weight: .medium, design: .default)

    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let bodyEmphasis = Font.system(size: 15, weight: .medium, design: .default)

    static let secondaryBody = Font.system(size: 13, weight: .regular, design: .default)
    static let secondaryBodyEmphasis = Font.system(size: 13, weight: .medium, design: .default)

    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let captionEmphasis = Font.system(size: 11, weight: .medium, design: .default)

    static let monospacedBody = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let monospacedCaption = Font.system(size: 11, weight: .regular, design: .monospaced)

    static let editorFontFamily = "SoftdraftEditorMono"
    static let editorFontSize: CGFloat = 15
    static let editorLineHeight: CGFloat = 1.6

    static func previewHeading(for level: Int) -> Font {
        switch level {
        case 1:
            return primaryTitle
        case 2:
            return secondaryHeading
        default:
            return bodyEmphasis
        }
    }
}
