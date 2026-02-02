//
//  PreviewBlockRenderer.swift
//  SoftDraft
//
//  Created by Matt Adams on 02/02/2026.
//

import SwiftUI

protocol PreviewBlockRenderer {
    func renderBlock(_ block: MarkdownBlock) -> AnyView
}
