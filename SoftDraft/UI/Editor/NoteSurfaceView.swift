//
//  NoteSurfaceView.swift
//  SoftDraft
//
//  Created by Matt Adams on 24/01/2026.
//

import SwiftUI

import SwiftUI

struct NoteSurfaceView: View {

    let noteID: String?

    var body: some View {
        Group {
            if let noteID {
                NoteEditorView(noteID: noteID)
            } else {
                EmptyNotePlaceholder()
            }
        }
    }
}

struct EmptyNotePlaceholder: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Select a note")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

