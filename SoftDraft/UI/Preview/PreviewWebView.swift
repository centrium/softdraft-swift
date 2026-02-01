import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {

    let html: String

    func makeNSView(context: Context) -> WKWebView {

        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)

        // ───────── Lock it down ─────────

        // Transparent background
        webView.setValue(false, forKey: "drawsBackground")

        // No navigation gestures
        webView.allowsBackForwardNavigationGestures = false

        // Disable text magnification (prevents zoom feel)
        webView.allowsMagnification = false

        // ───────── Scroll behaviour (macOS) ─────────
        if let scrollView = webView.enclosingScrollView {
            scrollView.drawsBackground = false
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

func makePreviewHTML(body: String) -> String {
    """
    <!doctype html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">

        <style>
            :root {
                color-scheme: light dark;
            }

            body {
                margin: 0;
                padding: 48px 56px 80px;
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui;
                font-size: 16px;
                line-height: 1.7;
                background: transparent;
                color: rgba(0,0,0,0.85);
            }

            @media (prefers-color-scheme: dark) {
                body {
                    color: rgba(255,255,255,0.85);
                }
            }

            h1, h2, h3 {
                font-weight: 600;
                line-height: 1.3;
                margin-top: 2.2em;
                margin-bottom: 0.6em;
            }

            h1 { font-size: 1.8em; }
            h2 { font-size: 1.4em; }
            h3 { font-size: 1.2em; }

            p {
                margin: 0 0 1em 0;
            }

            pre {
                background: rgba(0,0,0,0.04);
                padding: 12px 14px;
                border-radius: 8px;
                overflow-x: auto;
                font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
                font-size: 0.95em;
            }

            code {
                font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
                font-size: 0.95em;
            }

            a {
                color: inherit;
                text-decoration: underline;
                text-underline-offset: 3px;
            }

            blockquote {
                margin: 1.5em 0;
                padding-left: 16px;
                border-left: 3px solid rgba(0,0,0,0.15);
                color: rgba(0,0,0,0.7);
            }

            @media (prefers-color-scheme: dark) {
                blockquote {
                    border-left-color: rgba(255,255,255,0.25);
                    color: rgba(255,255,255,0.7);
                }

                pre {
                    background: rgba(255,255,255,0.06);
                }
            }
        </style>
    </head>

    <body>
        \(body)
    </body>
    </html>
    """
}
