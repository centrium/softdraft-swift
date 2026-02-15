//
//  BlockImageView.swift
//  SoftDraft
//
//  Created by Matt Adams on 07/02/2026.
//


import SwiftUI
import AppKit

struct BlockImageView: View {
    let image: MarkdownImage
    let libraryURL: URL?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {

            // Image
            imageView
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Optional caption (very subtle)
            if let title = image.alt, !title.isEmpty {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = remoteURL {

            // Remote image (future-proof)
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }

        } else if let localURL = resolvedLocalURL,
                  let nsImage = NSImage(contentsOf: localURL) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            placeholder
        }
    }

    private var remoteURL: URL? {
        guard let url = URL(string: image.source),
              let scheme = url.scheme,
              !scheme.isEmpty
        else { return nil }
        return url
    }

    private var resolvedLocalURL: URL? {
        if image.source.hasPrefix("/") {
            return URL(fileURLWithPath: image.source)
        }

        guard let base = libraryURL else { return nil }

        let relative = URL(fileURLWithPath: image.source, relativeTo: base)
        return relative.standardizedFileURL
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(AppTones.raisedSurface(for: colorScheme))
            .overlay(
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            )
            .frame(height: 180)
    }
}
