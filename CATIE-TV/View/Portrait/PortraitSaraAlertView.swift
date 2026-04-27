//
//  PortraitSaraAlertView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import AVKit
import CocoaLumberjackSwift
import SwiftUI

// MARK: - FlashingController

/// Flashing controller class to properly manage animation state
class FlashingController: ObservableObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("FlashingController : deinit called")
        // Just invalidate the timer without calling stopFlashing
        // to avoid potential retain cycles during deinit
        timer?.invalidate()
        timer = nil
    }

    // MARK: Internal

    @Published var isFlashing: Bool = false

    func startFlashing(duration: TimeInterval) {
        stopFlashing() // Clean up existing timer

        DDLogDebug("FlashingController : Starting SARA Alert flashing animation")

        // Start with flashing on
        DispatchQueue.main.async { [weak self] in
            self?.isFlashing = true
        }

        // Use a weak reference to self in the timer creation
        // to avoid strong reference cycles
        weak var weakSelf = self
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { _ in
            // Use the weak reference instead of capturing self in the closure
            guard let self = weakSelf else {
                return
            }

            // Use weak self in the dispatch closure as well
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                withAnimation(.easeInOut(duration: duration / 2)) {
                    self.isFlashing.toggle()
                }
            }
        }

        // Make sure the timer doesn't get suspended
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopFlashing() {
        if let t = timer {
            t.invalidate()
        }
        timer = nil

        // Use weak self in the dispatch closure
        DispatchQueue.main.async { [weak self] in
            self?.isFlashing = false
        }
    }

    // MARK: Private

    private var timer: Timer?
}

// MARK: - PortraitSaraAlertOverlay

/// Overlay component for displaying SARA Alerts with animations
struct PortraitSaraAlertOverlay: View {
    // MARK: Internal

    /// Indicates whether the SARA alert is presented
    let isSaraAlertPresented: Bool

    /// The SARA alert header to display
    let saraAlertHeader: String

    /// The SARA alert message to display
    let saraAlertMessage: String

    /// The SARA alert footer to display
    let saraAlertFooter: String

    /// The SARA alert border color
    let saraAlertBorderColor: Color

    /// The SARA alert border width
    let saraAlertBorderWidth: CGFloat

    /// The SARA alert body background color
    let saraAlertBodyBackgroundColor: Color

    /// The SARA alert body text color
    let saraAlertBodyTextColor: Color

    /// The SARA alert footer background color
    let saraAlertFooterBackgroundColor: Color

    /// The SARA alert footer text color
    let saraAlertFooterTextColor: Color

    /// The SARA alert header font size
    let saraAlertHeaderFontSize: CGFloat

    /// The SARA alert header font style
    let saraAlertHeaderFontStyle: String

    /// The SARA alert footer font size
    let saraAlertFooterFontSize: CGFloat

    /// The SARA alert footer font style
    let saraAlertFooterFontStyle: String

    /// The SARA alert body font size
    let saraAlertBodyFontSize: CGFloat

    /// Indicates whether the SARA alert has rich text
    let saraAlertHasRichText: Bool

    /// The SARA alert body text components
    let saraAlertBodyTextComponents: [PortraitViewModel.BodyTextComponent]

    /// Indicates whether the SARA alert is flashing
    let saraAlertFlashing: Bool

    /// The SARA alert flashing color
    let saraAlertFlashColor: Color

    /// Color scheme from environment
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Body

    var body: some View {
        Group {
            if isSaraAlertPresented {
                saraAlertBackdrop
                saraAlertContent
            }
        }
        .accessibilityIdentifier("saraAlertContainer")
    }

    // MARK: Private

    // MARK: - State Variables

    /// Offset for slide-in animation
    @State private var saraAlertOffset: CGFloat = 2000 // Start off-screen

    /// Opacity for fade-in animation
    @State private var saraAlertOpacity: Double = 0

    // MARK: - Background Backdrop

    private var saraAlertBackdrop: some View {
        Color.black
            .opacity(colorScheme == .dark ? 0.7 : 0.5)
            .edgesIgnoringSafeArea(.all)
            .transition(.opacity)
            .accessibilityIdentifier("saraAlertBackdrop")
    }

    // MARK: - Alert Content

    private var saraAlertContent: some View {
        GeometryReader { geometry in
            // Calculate alert size based on screen dimensions
            let alertWidth = geometry.size.height * 0.5
            let alertHeight = geometry.size.height * 0.5

            // Center the alert
            PortraitSaraAlertView(
                saraAlertHeader: saraAlertHeader,
                saraAlertMessage: saraAlertMessage,
                saraAlertFooter: saraAlertFooter,
                saraAlertFlashing: saraAlertFlashing,
                saraAlertFlashColor: saraAlertFlashColor,
                saraAlertBorderColor: saraAlertBorderColor,
                saraAlertBorderWidth: saraAlertBorderWidth,
                saraAlertBodyBackgroundColor: saraAlertBodyBackgroundColor,
                saraAlertBodyTextColor: saraAlertBodyTextColor,
                saraAlertFooterBackgroundColor: saraAlertFooterBackgroundColor,
                saraAlertFooterTextColor: saraAlertFooterTextColor,
                saraAlertHeaderFontSize: saraAlertHeaderFontSize,
                saraAlertHeaderFontStyle: saraAlertHeaderFontStyle,
                saraAlertFooterFontSize: saraAlertFooterFontSize,
                saraAlertFooterFontStyle: saraAlertFooterFontStyle,
                saraAlertBodyFontSize: saraAlertBodyFontSize,
                saraAlertHasRichText: saraAlertHasRichText,
                saraAlertBodyTextComponents: saraAlertBodyTextComponents
            )
            .frame(width: alertWidth, height: alertHeight)
            .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
            .offset(y: saraAlertOffset)
            .opacity(saraAlertOpacity)
            .environment(\.colorScheme, colorScheme) // Pass color scheme to the alert
            .accessibilityIdentifier("saraAlertPositionWrapper")
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: saraAlertOffset)
        .animation(.easeIn, value: saraAlertOpacity)
        .accessibilityIdentifier("saraAlertContentWrapper")
        .onAppear {
            // Animate the alert sliding in from bottom
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    saraAlertOffset = 0
                    saraAlertOpacity = 1
                }
            }
        }
    }
}

// MARK: - PortraitSaraAlertView

struct PortraitSaraAlertView: View {
    // MARK: Internal

    /// The SARA alert type to display
    let saraAlertHeader: String

    /// The SARA alert message to display
    let saraAlertMessage: String

    /// The SARA alert footer to display
    let saraAlertFooter: String

    /// Indicates whether the SARA alert is flashing
    let saraAlertFlashing: Bool

    /// The SARA alert flashing color
    let saraAlertFlashColor: Color

    /// The SARA alert border color
    let saraAlertBorderColor: Color

    /// The SARA alert border width
    let saraAlertBorderWidth: CGFloat

    /// The SARA alert body background color
    let saraAlertBodyBackgroundColor: Color

    /// The SARA alert body text color
    let saraAlertBodyTextColor: Color

    /// The SARA alert footer background color
    let saraAlertFooterBackgroundColor: Color

    /// The SARA alert footer text color
    let saraAlertFooterTextColor: Color

    /// The SARA alert header font size
    let saraAlertHeaderFontSize: CGFloat

    /// The SARA alert header font style
    let saraAlertHeaderFontStyle: String

    /// The SARA alert footer font size
    let saraAlertFooterFontSize: CGFloat

    /// The SARA alert footer font style
    let saraAlertFooterFontStyle: String

    /// The SARA alert body font size
    let saraAlertBodyFontSize: CGFloat

    /// Indicates whether the SARA alert has rich text
    let saraAlertHasRichText: Bool

    /// The SARA alert body text components
    let saraAlertBodyTextComponents: [PortraitViewModel.BodyTextComponent]

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main alert container with proper background clipping
                VStack(spacing: 0) {
                    // Header
                    headerView()

                    // Horizontal divider between header and body
                    Rectangle()
                        .fill(currentBorderColor)
                        .frame(height: borderWidth)
                        .accessibilityIdentifier("headerBodyDivider")

                    // Body
                    bodyView(geometry: geometry)

                    // Horizontal divider between body and footer
                    Rectangle()
                        .fill(currentBorderColor)
                        .frame(height: borderWidth)
                        .accessibilityIdentifier("bodyFooterDivider")

                    // Footer
                    footerView(geometry: geometry)
                }
                .background(
                    // Use RoundedRectangle with proper fill to ensure background doesn't extend beyond border
                    RoundedRectangle(cornerRadius: 0)
                        .fill(alertBackgroundColor)
                        .accessibilityIdentifier("saraAlertBackground")
                )
                .overlay(
                    // Border overlay with proper corner radius
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(
                            currentBorderColor,
                            lineWidth: outerBorderWidth
                        )
                        .accessibilityIdentifier("saraAlertBorder")
                )
                .clipShape(RoundedRectangle(cornerRadius: 0)) // Ensure content is clipped to shape
                .onChange(of: saraAlertFlashing) { isFlashing in
                    if isFlashing {
                        flashingController.startFlashing(duration: flashDuration)
                    } else {
                        flashingController.stopFlashing()
                    }
                }
                .onAppear {
                    // Start flashing animation if needed
                    if saraAlertFlashing {
                        flashingController.startFlashing(duration: flashDuration)
                        DDLogDebug("PortraitSaraAlertView : SARA Alert starting flashing on appear, status: \(saraAlertFlashing)")
                    }
                }
                .onDisappear {
                    // Clean up when alert disappears
                    flashingController.stopFlashing()
                }
                .accessibilityIdentifier("saraAlertMainContainer")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityIdentifier("saraAlertGeometryWrapper")
        }
        .accessibilityIdentifier("portraitSaraAlertView")
    }

    // MARK: Private

    /// Use StateObject for flash controller to maintain state across view updates
    @StateObject private var flashingController = FlashingController()

    /// Constants for animation
    private let flashDuration: Double = 1.0

    /// Calculate dynamic border width
    private var borderWidth: CGFloat {
        saraAlertBorderWidth > 0 ? saraAlertBorderWidth : 15.0 // Original width for inner borders
    }

    /// Calculate outer border width (doubled)
    private var outerBorderWidth: CGFloat {
        let baseBorderWidth = saraAlertBorderWidth > 0 ? saraAlertBorderWidth : 15.0
        return baseBorderWidth * 2.0 // Double the border width for outer border only
    }

    // MARK: - Alert Theme Colors

    private var alertBackgroundColor: Color {
        saraAlertBodyBackgroundColor
    }

    /// Add this computed property to handle flashing border color
    private var currentBorderColor: Color {
        if flashingController.isFlashing, saraAlertFlashing {
            saraAlertBorderColor
        } else {
            saraAlertFlashColor
        }
    }

    private var alertHeaderTextColor: Color {
        saraAlertBodyTextColor
    }

    private var alertBodyTextColor: Color {
        saraAlertBodyTextColor
    }

    private var alertFooterTextColor: Color {
        saraAlertFooterTextColor
    }

    private var alertFooterBackgroundColor: Color {
        saraAlertFooterBackgroundColor
    }

    // MARK: - Component Views

    private func headerView() -> some View {
        ZStack {
            Text(saraAlertHeader)
                .font(.custom(saraAlertHeaderFontStyle.contains("italic") ? "Poppins-BoldItalic" : "Poppins-Bold", size: saraAlertHeaderFontSize))
                .if(saraAlertHeaderFontStyle.contains("underline")) { _ in
                    if #available(tvOS 16.0, *) {
                        Text(saraAlertHeader)
                            .underline(true, pattern: .solid, color: nil)
                    } else {
                        Text(saraAlertHeader)
                            .underline()
                    }
                }
                .foregroundColor(alertHeaderTextColor)
                .multilineTextAlignment(.center)
                .padding(20)
                .accessibilityIdentifier("saraAlertHeaderText")
        }
        .accessibilityIdentifier("saraAlertHeader")
    }

    private func bodyView(geometry: GeometryProxy) -> some View {
        // Account for the two divider borders (header-body and body-footer)
        let totalDividerHeight = borderWidth * 2
        // Body takes the remaining space after header (15%) and footer (15%) and dividers
        let bodyHeight = geometry.size.height * 0.7 - totalDividerHeight

        return VStack {
            // Body content with scrolling support
            ScrollView {
                // Conditional content extraction
                if saraAlertHasRichText {
                    richTextContentView()
                } else {
                    simpleTextContentView()
                }
            }
            .padding(30)
            .frame(
                minWidth: geometry.size.width,
                minHeight: bodyHeight
            )
            .accessibilityIdentifier("saraAlertBodyScrollView")
        }
        .frame(height: bodyHeight)
        .accessibilityIdentifier("saraAlertBody")
    }

    private func footerView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 6) {
            // Main footer content
            if !saraAlertFooter.isEmpty {
                footerTextView()
            }
        }
        .padding(20)
        .frame(height: geometry.size.height * 0.15) // Height is 15% of container
        .background(alertFooterBackgroundColor)
        .accessibilityIdentifier("saraAlertFooter")
    }

    private func footerTextView() -> some View {
        let isBold = saraAlertFooterFontStyle.contains("bold")
        let isItalic = saraAlertFooterFontStyle.contains("italic")

        // Compute the font outside the view builder
        let fontName =
            if isBold, isItalic {
                "Poppins-BoldItalic"
            } else if isBold {
                "Poppins-Bold"
            } else if isItalic {
                "Poppins-Italic"
            } else {
                "Poppins-Regular"
            }

        let font: Font = .custom(fontName, size: saraAlertFooterFontSize)

        return Text(saraAlertFooter)
            .font(font)
            .foregroundColor(alertFooterTextColor)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("saraAlertFooterText")
    }

    private func richTextContentView() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(0 ..< saraAlertBodyTextComponents.count, id: \.self) { index in
                richTextComponent(component: saraAlertBodyTextComponents[index])
                    .accessibilityIdentifier("saraAlertRichTextComponent\(index)")
            }
        }
        .accessibilityIdentifier("saraAlertRichTextContainer")
    }

    @ViewBuilder
    private func richTextComponent(component: PortraitViewModel.BodyTextComponent) -> some View {
        let isBold = component.fontStyle.contains("bold")
        let isItalic = component.fontStyle.contains("italic")
        let isUnderlined = component.fontStyle.contains("underline")

        let fontName =
            if isBold, isItalic {
                "Poppins-BoldItalic"
            } else if isBold {
                "Poppins-Bold"
            } else if isItalic {
                "Poppins-Italic"
            } else {
                "Poppins-Regular"
            }

        let font: Font = .custom(fontName, size: component.fontSize)

        let text = Text(component.text)
            .font(font)
            .underline(isUnderlined)
            .foregroundColor(component.color)
            .multilineTextAlignment(component.alignment)

        text
            .frame(maxWidth: .infinity, alignment: convertAlignment(component.alignment))
            .accessibilityIdentifier("saraAlertRichTextComponent")
    }

    private func simpleTextContentView() -> some View {
        Text(saraAlertMessage)
            .font(.custom("Poppins-Regular", size: saraAlertBodyFontSize))
            .foregroundColor(alertBodyTextColor)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("saraAlertSimpleText")
    }

    private func convertAlignment(_ textAlignment: TextAlignment) -> Alignment {
        switch textAlignment {
        case .leading:
            .leading
        case .trailing:
            .trailing
        case .center:
            .center
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct PortraitSaraAlertOverlay_Previews: PreviewProvider {
        static var previews: some View {
            PortraitSaraAlertOverlay(
                isSaraAlertPresented: true,
                saraAlertHeader: "SARA ALERT",
                saraAlertMessage: "This is a test alert message. Please remain calm and follow instructions.",
                saraAlertFooter: "Test Footer",
                saraAlertBorderColor: .black,
                saraAlertBorderWidth: 10.0,
                saraAlertBodyBackgroundColor: .white,
                saraAlertBodyTextColor: .black,
                saraAlertFooterBackgroundColor: .blue,
                saraAlertFooterTextColor: .white,
                saraAlertHeaderFontSize: 24,
                saraAlertHeaderFontStyle: "bold",
                saraAlertFooterFontSize: 18,
                saraAlertFooterFontStyle: "regular",
                saraAlertBodyFontSize: 16,
                saraAlertHasRichText: false,
                saraAlertBodyTextComponents: [],
                saraAlertFlashing: true,
                saraAlertFlashColor: .black
            )
            .previewLayout(.fixed(width: 1920, height: 1080))
        }
    }
#endif
