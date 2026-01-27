import SwiftUI
import MarkdownEditor

struct NoteEditorView: View {

    @EnvironmentObject private var libraryManager: LibraryManager

    let noteID: String

    @State private var text: String = ""
    @State private var autosave = AutosaveController()
    @State private var isLoading = false

    var body: some View {
        MarkdownEditorView(
            text: $text,
            configuration: EditorConfiguration(
                fontFamily: "SoftdraftEditorMono",
                showLineNumbers: false
            )
        )
        .onChange(of: text) { _, newValue in
            guard !isLoading else { return }

            autosave.schedule {
                await save(content: newValue)
            }
        }
        .task(id: noteID) {
            await loadNote()
        }
    }

    // MARK: - Load

    private func loadNote() async {
        autosave.cancel()
        isLoading = true

        text = ""

        let loaded = await load()

        guard !Task.isCancelled else {
            isLoading = false
            return
        }

        text = loaded
        isLoading = false
    }

    // MARK: - Persistence

    private func load() async -> String {
        guard let libraryURL = libraryManager.activeLibraryURL else { return "" }

        return (try? NoteStore.load(
            libraryURL: libraryURL,
            noteID: noteID
        )) ?? ""
    }

    private func save(content: String) async {
        guard let libraryURL = libraryManager.activeLibraryURL else { return }

        try? NoteStore.save(
            libraryURL: libraryURL,
            noteID: noteID,
            content: content
        )
    }
}
