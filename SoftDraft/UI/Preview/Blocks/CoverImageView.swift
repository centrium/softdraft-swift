import SwiftUI
import AppKit

enum CoverVisibility: Equatable {
    case pending
    case visible
    case failed
}

struct CoverImageView: View {

    let image: MarkdownImage
    let libraryURL: URL?
    @Binding var visibility: CoverVisibility

    @Environment(\.colorScheme) private var colorScheme

    private let heroHeight: CGFloat = 320
    private let bottomFadeHeight: CGFloat = 180

    var body: some View {
        Group {
            if let remote = remoteURL {
                remoteImageView(url: remote)
            } else if let local = resolvedLocalURL {
                localImageView(at: local)
            } else {
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        visibility = .failed
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "Cover image")
    }

    private var accessibilityLabel: String? {
        guard let alt = image.alt, !alt.isEmpty else {
            return nil
        }
        return alt
    }

    @ViewBuilder
    private func localImageView(at url: URL) -> some View {
        if let nsImage = NSImage(contentsOf: url) {
            heroView(Image(nsImage: nsImage))
                .onAppear {
                    visibility = .visible
                }
        } else {
            Color.clear
                .frame(height: 0)
                .onAppear {
                    visibility = .failed
                }
        }
    }

    @ViewBuilder
    private func remoteImageView(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                heroView(image)
                    .onAppear {
                        visibility = .visible
                    }
            case .failure:
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        visibility = .failed
                    }
            case .empty:
                EmptyView()
            @unknown default:
                EmptyView()
            }
        }
    }

    private func heroView(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)
            .clipped()
            .overlay(gradientOverlay)
            .contentShape(Rectangle())
    }

    private var gradientOverlay: some View {
        let background = AppTones.previewSurface(for: colorScheme)

        return ZStack(alignment: .bottom) {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.2), location: 0.0),
                    .init(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), location: 0.55),
                    .init(color: Color.black.opacity(0.0), location: 0.75)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            // Bottom fade keeps the transition into the body feeling deliberate without masking the artwork.
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: background.opacity(0.0), location: 0.0),
                    .init(color: background.opacity(colorScheme == .dark ? 0.15 : 0.25), location: 0.45),
                    .init(color: background.opacity(colorScheme == .dark ? 0.85 : 0.92), location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: bottomFadeHeight)
        }
        .allowsHitTesting(false)
    }

    private var remoteURL: URL? {
        guard let url = URL(string: image.source),
              let scheme = url.scheme,
              !scheme.isEmpty,
              scheme != "file"
        else {
            return nil
        }
        return url
    }

    private var resolvedLocalURL: URL? {
        if image.source.hasPrefix("/") {
            return URL(fileURLWithPath: image.source)
        }

        guard let base = libraryURL else {
            return nil
        }

        let relative = URL(fileURLWithPath: image.source, relativeTo: base)
        return relative.standardizedFileURL
    }
}
