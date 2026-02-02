//
//  PreviewInlineRenderer.swift
//  SoftDraft
//
//  Created by Matt Adams on 02/02/2026.
//

import SwiftUI

protocol PreviewInlineRenderer {
    func renderInline(_ inline: MarkdownInline) -> AttributedString
}
