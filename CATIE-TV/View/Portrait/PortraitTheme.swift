//
//  PortraitTheme.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//
import SwiftUI

// MARK: - Color Theme System

struct PortraitTheme {
    // MARK: Lifecycle

    /// Initialize with the current color scheme
    init(colorScheme: ColorScheme) {
        isDarkMode = colorScheme == .dark
    }

    // MARK: Internal

    let isDarkMode: Bool

    var headerShadow: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.6)
    }

    var primaryText: Color {
        isDarkMode ? Color.white : blueThemeColor
    }

    /// Primary theme color
    var blueThemeColor: Color {
        Color(red: 0.1, green: 0.49, blue: 0.75)
    }

    var cardShadow: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.4)
    }

    /// Weather card gradients
    var weatherGradientStart: Color {
        isDarkMode ? Color(red: 0.3725, green: 0.3647, blue: 0.3647) : Color(red: 6 / 255, green: 79 / 255, blue: 101 / 255) // #064F65
    }

    var weatherGradientEnd: Color {
        isDarkMode ? Color(red: 0.2431, green: 0.2431, blue: 0.2431) : Color(red: 26 / 255, green: 125 / 255, blue: 191 / 255) // #1A7DBF
    }

    /// Event card colors
    var eventGradientStart: Color {
        Color(red: 0.3725, green: 0.3647, blue: 0.3647)
    }

    var eventGradientEnd: Color {
        Color(red: 0.2431, green: 0.2431, blue: 0.2431)
    }

    var activeEventGradientStart: Color {
        Color(red: 0.8, green: 0.2, blue: 0.2)
    }

    var activeEventGradientEnd: Color {
        isDarkMode ? Color(red: 0.4, green: 0.1, blue: 0.1) : Color(red: 0.6, green: 0.1, blue: 0.1)
    }

    /// Status indicator colors
    var statusCardBorder: Color {
        isDarkMode ? Color.white : blueThemeColor
    }

    var statusIndicatorActiveStart: Color {
        Color(red: 0.129, green: 0.808, blue: 0.043) // #21ce0b
    }

    var statusIndicatorActiveEnd: Color {
        Color(red: 0.047, green: 0.533, blue: 0.027) // #0c8807
    }

    var statusIndicatorText: Color {
        isDarkMode ? Color.white : blueThemeColor
    }

    var footerText: Color {
        isDarkMode ? Color.white : Color.black
    }

    /// Header background (use isDarkMode instead of colorScheme)
    var headerBackground: some View {
        Group {
            if isDarkMode {
                darkHeaderGradient
                    .accessibilityIdentifier("darkHeaderBackground")
            } else {
                Color.white
                    .accessibilityIdentifier("lightHeaderBackground")
            }
        }
        .accessibilityIdentifier("headerBackground")
    }

    /// Header background (use isDarkMode instead of colorScheme)
    var footerBackground: some View {
        Group {
            if isDarkMode {
                darkFooterGradient
                    .accessibilityIdentifier("darkFooterBackground")
            } else {
                Color.white
                    .accessibilityIdentifier("lightFooterBackground")
            }
        }
        .accessibilityIdentifier("footerBackground")
    }

    // MARK: Private

    /// 1. Define the gradient you want for dark mode
    private var darkHeaderGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black,
                Color(red: 62 / 255, green: 61 / 255, blue: 61 / 255),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var darkFooterGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 62 / 255, green: 61 / 255, blue: 61 / 255),
                Color.black,
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
