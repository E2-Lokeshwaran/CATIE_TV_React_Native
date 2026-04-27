//
//  ViewExtensions.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//
import SwiftUI

// MARK: - BlurView

/// Add a BlurView struct to create the blur effect in SwiftUI
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    var accessibilityIdentifier: String?

    func makeUIView(context _: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        if let identifier = accessibilityIdentifier {
            view.accessibilityIdentifier = identifier
        }
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context _: Context) {
        uiView.effect = UIBlurEffect(style: style)
        if let identifier = accessibilityIdentifier {
            uiView.accessibilityIdentifier = identifier
        }
    }
}

// MARK: - RoundedCorner

/// Custom shape for rounded corner support
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

/// View extension to apply rounded corners for specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/// Conditional modifier for easier conditional styling
extension View {
    @ViewBuilder func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
