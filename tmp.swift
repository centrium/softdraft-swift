import SwiftUI
import AppKit

var attr = AttributedString("Hello")
attr.font = .system(size: 15, weight: .bold)
attr.appKit.font = NSFont.systemFont(ofSize: 15, weight: .bold)
attr.foregroundColor = .red
attr.appKit.foregroundColor = NSColor.red

let ns = NSAttributedString(attr)
print(ns)
