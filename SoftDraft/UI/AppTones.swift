//
//  AppTones.swift
//  SoftDraft
//

import SwiftUI

enum AppTones {
    static func windowBackground(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(red: 0.12, green: 0.12, blue: 0.13)
        }
        return Color(red: 0.96, green: 0.95, blue: 0.94)
    }

    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(red: 0.10, green: 0.11, blue: 0.11)
        }
        return Color(red: 0.94, green: 0.93, blue: 0.91)
    }

    static func editorSurface(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(red: 0.13, green: 0.14, blue: 0.14)
        }
        return Color(red: 0.97, green: 0.96, blue: 0.95)
    }

    static func previewSurface(for colorScheme: ColorScheme) -> Color {
        editorSurface(for: colorScheme)
    }

    static func raisedSurface(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(red: 0.16, green: 0.16, blue: 0.17)
        }
        return Color(red: 0.95, green: 0.94, blue: 0.92)
    }

    static func badgeSurface(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.10)
        }
        return Color.black.opacity(0.06)
    }

    static func selectionFill(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(red: 0.56, green: 0.61, blue: 0.59).opacity(0.24)
        }
        return Color(red: 0.39, green: 0.46, blue: 0.42).opacity(0.14)
    }

    static func subtleDivider(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.16)
        }
        return Color.black.opacity(0.12)
    }

    static func subtleStroke(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.18)
        }
        return Color.black.opacity(0.10)
    }
}
