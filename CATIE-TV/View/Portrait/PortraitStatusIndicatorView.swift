//
//  PortraitStatusIndicatorView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import SwiftUI

// MARK: - PortraitStatusIndicatorView

struct PortraitStatusIndicatorView: View {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        indicators: [(String, String, Int)],
        theme: PortraitTheme,
        statusPerPage: Int = 4,

    ) {
        self.indicators = indicators
        self.theme = theme
        self.statusPerPage = statusPerPage
    }

    // MARK: Internal

    // MARK: - Status Indicator Row

    struct StatusIndicatorRow: View {
        let indicators: [(String, String, Int)]
        let currentPage: Int
        let statusPerPage: Int
        let geometry: GeometryProxy
        let theme: PortraitTheme
        let initialAnimationComplete: Bool
        let statusScrollingOffset: CGFloat
        let statusFadeOpacity: Double

        var body: some View {
            HStack(spacing: 10) {
                // Added safety check for empty indicators array
                if indicators.isEmpty {
                    // Handle empty state gracefully
                    EmptyView()
                        .accessibilityIdentifier("emptyStatusIndicators")
                } else {
                    // Safe indexing with bounds checking to prevent crashes
                    let safeStartIndex = max(0, min(currentPage * statusPerPage, indicators.count))
                    let safeEndIndex = min(safeStartIndex + statusPerPage, indicators.count)

                    // Only create the array slice if the range is valid and safe
                    let visibleIndicators: [(String, String, Int)] =
                        safeStartIndex < safeEndIndex && safeStartIndex >= 0 && safeEndIndex <= indicators.count
                            ? Array(indicators[safeStartIndex ..< safeEndIndex])
                            : []

                    // Calculate width based on fixed statusPerPage to maintain consistent grid layout
                    let actualIndicatorCount = visibleIndicators.count
                    let spacingCount = max(0, statusPerPage - 1)
                    let totalSpacing: CGFloat = 10 * CGFloat(spacingCount) // spacing between all cards (including placeholders)
                    let availableWidth = (geometry.size.width - 25) - totalSpacing
                    let cardWidth = availableWidth / CGFloat(statusPerPage)

                    // Calculate height based on original spacing (42) to keep height same
                    let originalTotalSpacing: CGFloat = 42 * CGFloat(spacingCount)
                    let originalAvailableWidth = geometry.size.width - originalTotalSpacing
                    let cardHeight = originalAvailableWidth / CGFloat(statusPerPage)

                    // Build cards for all slots (indicators + placeholders to maintain grid)
                    // Use safe indexing to prevent crashes with duplicate or malformed data
                    ForEach(0 ..< statusPerPage, id: \.self) { index in
                        if index < actualIndicatorCount, index < visibleIndicators.count {
                            // Show actual indicator with safe indexing
                            let indicator = visibleIndicators[index]
                            StatusCard(
                                title: indicator.0.isEmpty ? "Status" : indicator.0, // Fallback for empty titles
                                description: indicator.1.isEmpty ? "No description" : indicator.1, // Fallback for empty descriptions
                                status: indicator.2,
                                theme: theme
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            .accessibilityIdentifier("statusCard\(index)-\(indicator.0.replacingOccurrences(of: " ", with: "_"))") // Unique ID for duplicates
                        } else {
                            // Show placeholder to maintain grid layout
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: cardWidth, height: cardHeight)
                                .accessibilityIdentifier("statusCardPlaceholder\(index)")
                        }
                    }
                }
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 10)
            .frame(width: geometry.size.width - 25)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("statusIndicatorRow")
            // Use a combined offset for both animations
            .offset(x: initialAnimationComplete ? statusScrollingOffset : 1000)
            .opacity(statusFadeOpacity) // Keep the existing fade effect
        }
    }

    // MARK: - Status Card

    struct StatusCard: View {
        let title: String
        let description: String
        let status: Int
        let theme: PortraitTheme
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            VStack(spacing: 0) {
                Text(title.forceCharWrapping) // Force character wrapping for long titles
                    .font(.custom("Poppins-Bold", size: calculatePortraitFontSize(for: title)))
                    .foregroundColor(status == 1 ? .white : theme.statusIndicatorText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(10)
                    .accessibilityIdentifier("statusCardTitle")

                Spacer().frame(height: 5)

                // Use USMail for status 1, otherwise TechTalk
                Image(status == 1 ? "USMail" : "TechTalk")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 35)
                    .foregroundColor(status == 1 ? .white : theme.statusIndicatorText)
                    .padding(.vertical, 3)
                    .accessibilityIdentifier("statusCardIcon")

                Spacer().frame(height: 5)

                // Make the text view take available horizontal space with fixed height
                Text(description.forceCharWrapping)
                    .font(.custom("Poppins-Medium", size: 16))
                    .foregroundColor(status == 1 ? .white : theme.statusIndicatorText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(12)
                    .accessibilityIdentifier("statusCardDescription")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
            .background(
                Group {
                    if status == 1 {
                        // Gradient background for status 1
                        LinearGradient(
                            gradient: Gradient(colors: [
                                theme.statusIndicatorActiveStart,
                                theme.statusIndicatorActiveEnd,
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.clear
                    }
                }
                .accessibilityIdentifier("statusCardBackground")
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(status != 1 ? theme.statusCardBorder : Color.clear, lineWidth: 1)
                    .accessibilityIdentifier("statusCardBorder")
            )
            .cornerRadius(5)
            .shadow(color: theme.cardShadow, radius: 3, x: 0, y: 2)
            .accessibilityIdentifier(status == 1 ? "activeStatusCard" : "inactiveStatusCard")
        }

        // MARK: - Helper Functions

        /// Calculate appropriate font size for portrait status indicator titles
        private func calculatePortraitFontSize(for text: String) -> CGFloat {
            let uppercaseRatio = Double(text.filter(\.isUppercase).count) / Double(text.count)
            let hasManyCaps = uppercaseRatio > 0.6 // More than 60% capitals

            let baseFontSize: CGFloat =
                if hasManyCaps {
                    // Extra small fonts for texts with many capitals (using Poppins-Bold range)
                    text.count > 35 ? 12 : (text.count > 25 ? 12 : 14)
                } else {
                    // Normal sizing for mixed case (using Poppins-Bold range)
                    text.count > 30 ? 14 : (text.count > 20 ? 14 : 16)
                }

            return max(10, min(16, baseFontSize)) // Portrait range: 10-16pt
        }
    }

    /// Status indicator data from parent
    let indicators: [(String, String, Int)]

    /// Theme to use for styling
    let theme: PortraitTheme

    /// Define constants for pagination
    let statusPerPage: Int

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Text("Status Indicator")
                .font(.custom("Poppins-Bold", size: 24))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .accessibilityIdentifier("statusIndicatorHeaderText")

            statusIndicatorContent
        }
        .accessibilityIdentifier("portraitStatusIndicatorView")
        .id("statusIndicators-\(indicators.count)-\(indicators.map { "\($0.0)-\($0.1)-\($0.2)" }.joined(separator: "|"))") // Force SwiftUI to recognize data changes
        .onAppear {
            handleStatusIndicatorAppear()
        }
        .onDisappear {
            // Clean up timer when view disappears
            statusScrollTimer?.invalidate()
            statusScrollTimer = nil
        }
        .onChange(of: indicators.count) { newCount in
            DDLogDebug("PortraitStatusIndicatorView: Indicator count changed to \(newCount)")
            handleIndicatorCountChange(newCount: newCount)
        }
    }

    // MARK: Private

    // MARK: - Animation Timing Constants

    private enum AnimationTiming {
        static let scrollDuration: Double = 0.8
        static let fadeOutDelay: Double = 0.75 // When to start fade out
        static let fadeOutDuration: Double = 0.05
        static let resetDelay: Double = 0.85 // When to reset position
        static let fadeInDuration: Double = 0.4
    }

    // MARK: - State Variables

    /// Offset for slide-in animation
    @State private var statusSlideInOffset: CGFloat = 1000

    /// Whether initial animation has completed
    @State private var initialAnimationComplete: Bool = false

    /// Opacity for fade effect
    @State private var statusFadeOpacity: Double = 1.0

    /// Status indicator scrolling variables
    @State private var statusScrollTimer: Timer?
    @State private var statusCurrentPage: Int = 0
    @State private var statusTotalPages: Int = 1
    @State private var statusScrollingOffset: CGFloat = 0

    // MARK: - Content Views

    private var statusIndicatorContent: some View {
        // Wrap in a proper clipping container
        ZStack(alignment: .leading) {
            // Use GeometryReader for precise sizing
            GeometryReader { geometry in
                // Page container with absolute sizing and clipping
                StatusIndicatorRow(
                    indicators: indicators,
                    currentPage: statusCurrentPage,
                    statusPerPage: statusPerPage,
                    geometry: geometry,
                    theme: theme,
                    initialAnimationComplete: initialAnimationComplete,
                    statusScrollingOffset: statusScrollingOffset,
                    statusFadeOpacity: statusFadeOpacity
                )
                .accessibilityIdentifier("statusIndicatorRowContainer")
            }
            .frame(height: 210)
            .accessibilityIdentifier("statusIndicatorGeometryContainer")
        }
        // Crucial: Apply clipping to prevent content from appearing outside boundaries
        .clipShape(Rectangle())
        .background(Color.clear)
        .padding(.bottom, 15)
        .accessibilityIdentifier("statusIndicatorContent")
    }

    // MARK: - Methods

    private func handleStatusIndicatorAppear() {
        // Reset pagination variables
        statusCurrentPage = 0
        statusScrollingOffset = 0
        statusFadeOpacity = 1.0
        initialAnimationComplete = false

        // Calculate total pages with safety checks
        let totalIndicators = max(0, indicators.count) // Ensure non-negative count
        statusTotalPages = totalIndicators > 0 ? max(1, (totalIndicators + statusPerPage - 1) / statusPerPage) : 1
        DDLogDebug("PortraitStatusIndicatorView: onAppear with \(totalIndicators) indicators, \(statusTotalPages) pages")

        // Log indicator details for debugging (safely handle potential duplicates)
        for (index, indicator) in indicators.enumerated() {
            let safeTitle = indicator.0.isEmpty ? "<empty>" : indicator.0
            let safeDescription = indicator.1.isEmpty ? "<empty>" : indicator.1
            DDLogDebug("PortraitStatusIndicatorView: Indicator \(index): \(safeTitle) | \(safeDescription) | \(indicator.2)")
        }

        // Force the slide-in animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            statusSlideInOffset = 0 // Animate to position
        }

        // Mark the initial animation as complete after it finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            initialAnimationComplete = true

            // Recalculate indicators count in case it changed during animation
            let currentIndicatorCount = indicators.count
            DDLogDebug("PortraitStatusIndicatorView: Initial animation complete, current indicators: \(currentIndicatorCount)")

            // Only set up auto-scrolling if we have more than 4 indicators
            if currentIndicatorCount > statusPerPage {
                // Cancel any existing timer first
                statusScrollTimer?.invalidate()
                setupStatusScrollTimer()
            }
        }
    }

    private func setupStatusScrollTimer() {
        // Make sure to cancel any existing timer
        statusScrollTimer?.invalidate()

        DDLogDebug("PortraitStatusIndicatorView : Setting up status scroll timer")

        // Set up a new timer to change pages every 5 seconds
        statusScrollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [self] _ in
            // Only proceed if we have more than one page and initial animation is complete
            if statusTotalPages > 1, initialAnimationComplete {
                // Calculate the next page
                let nextPage = (statusCurrentPage + 1) % statusTotalPages

                // For rotated view (90 degrees), use height instead of width
                // Account for the rotation by using the height dimension for horizontal movement
                let pageWidth = UIScreen.main.bounds.height - 120 // Account for padding in rotated view

                // Step 1: Scroll to the next page
                withAnimation(.easeInOut(duration: AnimationTiming.scrollDuration)) {
                    statusScrollingOffset = -pageWidth // Scroll to next page
                }

                // Step 2: Just as content scrolls off-screen, make it invisible
                DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.fadeOutDelay) {
                    withAnimation(.easeOut(duration: AnimationTiming.fadeOutDuration)) {
                        statusFadeOpacity = 0.0 // Make invisible just at the end
                    }
                }

                // Step 3: After scroll completes, reset position and update page
                DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.resetDelay) {
                    // Update current page while invisible
                    statusCurrentPage = nextPage

                    // Reset position without animation
                    withAnimation(.none) {
                        statusScrollingOffset = 0
                    }

                    // Step 4: Fade in the new page
                    withAnimation(.easeIn(duration: AnimationTiming.fadeInDuration)) {
                        statusFadeOpacity = 1.0 // Fade in new content
                    }
                }
            }
        }
    }

    /// Handle dynamic changes in indicator count and update scrolling behavior accordingly
    private func handleIndicatorCountChange(newCount: Int) {
        DDLogDebug("PortraitStatusIndicatorView: Handling indicator count change to \(newCount)")

        // Cancel existing timer first
        statusScrollTimer?.invalidate()
        statusScrollTimer = nil

        // Recalculate total pages based on new count
        let totalIndicators = max(0, newCount)
        let newTotalPages = totalIndicators > 0 ? max(1, (totalIndicators + statusPerPage - 1) / statusPerPage) : 1

        DDLogDebug("PortraitStatusIndicatorView: New page count: \(newTotalPages) (was: \(statusTotalPages))")

        // Update pagination state
        statusTotalPages = newTotalPages
        statusCurrentPage = min(statusCurrentPage, statusTotalPages - 1) // Ensure current page is valid

        // Reset animations if needed
        statusScrollingOffset = 0
        statusFadeOpacity = 1.0

        // Only set up auto-scrolling if we have more than 4 indicators AND initial animation is complete
        if totalIndicators > statusPerPage, initialAnimationComplete {
            DDLogDebug("PortraitStatusIndicatorView: Setting up auto-scroll for \(totalIndicators) indicators")
            setupStatusScrollTimer()
        } else if totalIndicators <= statusPerPage {
            DDLogDebug("PortraitStatusIndicatorView: No auto-scroll needed for \(totalIndicators) indicators")
        } else {
            DDLogDebug("PortraitStatusIndicatorView: Waiting for initial animation to complete before setting up auto-scroll")
            // Set up a delayed check in case animation completes soon
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if initialAnimationComplete, indicators.count > statusPerPage {
                    DDLogDebug("PortraitStatusIndicatorView: Delayed auto-scroll setup for \(indicators.count) indicators")
                    statusScrollTimer?.invalidate()
                    setupStatusScrollTimer()
                }
            }
        }
    }
}

extension String {
    /// Forces the string to apply the break by character mode.
    ///
    /// Text("This is a long text.".forceCharWrapping)
    var forceCharWrapping: Self {
        map { String($0) }.joined(separator: "\u{200B}")
    }
}

// MARK: - Preview

#if DEBUG
    struct PortraitStatusIndicatorView_Previews: PreviewProvider {
        static var theme = PortraitTheme(colorScheme: .light)

        static var indicators: [(String, String, Int)] = [
            ("Normal", "Systems operating normally", 0),
            ("Warning", "Battery level low", 1),
            ("Error", "Network connection failed", 2),
            ("Info", "Updates available", 3),
            ("Alert", "Temperature above normal", 1),
        ]

        static var previews: some View {
            PortraitStatusIndicatorView(
                indicators: indicators,
                theme: theme
            )
            .previewLayout(.fixed(width: 800, height: 300))
        }
    }
#endif
