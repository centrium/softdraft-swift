# Markdown Feature Mapping

| Markdown feature | AST node |
| --- | --- |
| Document root | `MarkdownBlock.document(blocks:)` wrapping all top-level blocks |
| Paragraph text | `MarkdownBlock.paragraph(inlines:)` |
| Headings `#`-`######` | `MarkdownBlock.heading(level:inlines:)` |
| Block quotes `>` | `MarkdownBlock.blockQuote(children:)` |
| Unordered lists `-`, `*`, `+` | `MarkdownBlock.list(style: .unordered, items:)` |
| Ordered lists `1.` / `1)` | `MarkdownBlock.list(style: .ordered(start:), items:)` |
| List items | `MarkdownListEntry.listItem` wrapping `MarkdownListItem` |
| Task list items `- [ ] Task` | `MarkdownListEntry.taskItem` (`type: "taskItem"`) |
| Fenced / indented code blocks | `MarkdownBlock.codeBlock(language:source:)` |
| Horizontal rules `---`, `***`, `___` | `MarkdownBlock.thematicBreak` |
| Tables (header + GFM align row) | `MarkdownBlock.table(MarkdownTable)` with header/body rows + alignments |
| Standalone images | `MarkdownBlock.image(MarkdownImage)` |
| Inline images `![alt](src)` | `MarkdownInline.image(MarkdownImage)` |
| Links `[title](url "title")` | `MarkdownInline.link(MarkdownLink)` |
| Inline emphasis `*`/`_` | `MarkdownInline.emphasis` |
| Inline strong `**`/`__` | `MarkdownInline.strong` |
| Inline code `` `code` `` | `MarkdownInline.inlineCode` |
| Inline highlight `==text==` | `MarkdownInline.highlight([MarkdownInline])` |
| Inline strikethrough `~~text~~` | `MarkdownInline.strikethrough([MarkdownInline])` |
| Mermaid blocks ```mermaid``` | `MarkdownBlock.mermaidBlock(source:)` |
| Block math `$$ ... $$` or ```math``` | `MarkdownBlock.mathBlock(source:)` |
| Inline math `$...$` | `MarkdownInline.mathInline(String)` |

Bare `http://` or `https://` URLs in plain text are parsed into `.link` nodes so previews can style them consistently. Malformed or partial math delimiters still remain `.text` so the editor never emits half-finished math nodes.
