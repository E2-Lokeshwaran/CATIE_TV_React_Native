//
//  AutoScrollingScrollView.swift
//  CATIE-TV
//
//  Created by Harish on 09/05/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import SwiftUI

/// A custom ScrollView that implements smooth auto-scrolling specifically optimized for tvOS
struct AutoScrollingScrollView<Content: View>: UIViewRepresentable {
    // MARK: Lifecycle

    init(
        identifier: String,
        scrollDuration: TimeInterval,
        scrollDelay: TimeInterval = 0.0,
        continuousScrolling: Bool = false,
        onScrollComplete: @escaping () -> Void,
        hasLessThanThreeEvent: Bool = false,
        eventCount: Int? = nil,
        weatherForecastCount: Int? = nil,
        weatherTodayCount: Int? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onScrollComplete = onScrollComplete
        self.scrollDuration = scrollDuration
        self.scrollDelay = scrollDelay
        self.identifier = identifier
        self.hasLessThanThreeEvent = hasLessThanThreeEvent
        self.continuousScrolling = continuousScrolling
        self.eventCount = eventCount
        self.weatherForecastCount = weatherForecastCount
        self.weatherTodayCount = weatherTodayCount
    }

    // MARK: Internal

    /// Custom scroll view class that optimizes for smooth scrolling
    class OptimizedScrollView: UIScrollView {
        override func layoutSubviews() {
            super.layoutSubviews()
            // Prevent multiple layout updates by decelerating gradually
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        // MARK: Lifecycle

        init(onScrollComplete: @escaping () -> Void) {
            self.onScrollComplete = onScrollComplete
        }

        // MARK: Internal

        var hostingController: UIHostingController<Content>?
        var scrollView: UIScrollView?
        var contentHeight: CGFloat = 0
        var viewportHeight: CGFloat = 0
        var didStartScroll = false
        var didCompleteScroll = false
        var completionWorkItem: DispatchWorkItem?
        var scrollDelayWorkItem: DispatchWorkItem?
        var contentSizeCheckCounter = 0 // Track content size check attempts
        var maxContentSizeChecks = 5 // Max number of checks
        var isAnimating = false
        var continuousScrolling = false
        var cycleCount = 0 // Track scroll cycles for continuous mode
        var eventCount: Int? // Store event count for height calculation
        var weatherForecastCount: Int? // Store weather forecast count
        var weatherTodayCount: Int? // Store weather today count
        let onScrollComplete: () -> Void

        func cancelScrolling() {
            completionWorkItem?.cancel()
            completionWorkItem = nil
            scrollDelayWorkItem?.cancel()
            scrollDelayWorkItem = nil
            scrollView?.layer.removeAllAnimations()
            isAnimating = false
            // Reset all animation state to prevent stacking
            didStartScroll = false
            didCompleteScroll = false
            cycleCount = 0
        }

        func startSmoothScrolling(duration: TimeInterval, delay: TimeInterval, identifier: String) {
            // Prevent multiple calls when already animating or already started (except for initial continuous setup)
            guard let scrollView else {
                return
            }

            // If already animating, cancel existing animation first to prevent stacking
            if isAnimating {
                DDLogDebug("\(identifier): Already animating, ignoring start request")
                return
            }

            // For continuous scrolling, only allow restart if we're not currently scrolling
            if continuousScrolling, didStartScroll, !didCompleteScroll {
                DDLogDebug("\(identifier): Continuous scroll already in progress, ignoring start request")
                return
            }

            // For non-continuous, only start if we haven't started yet
            if !continuousScrolling, didStartScroll {
                DDLogDebug("\(identifier): Non-continuous scroll already started, ignoring start request")
                return
            }

            didStartScroll = true

            // Calculate the exact scrollable amount to show all content
            let scrollableAmount = max(0, contentHeight - viewportHeight)

            // If nothing to scroll, wait for the full duration before calling completion
            if scrollableAmount <= 0 {
                didCompleteScroll = !continuousScrolling // In continuous mode, we never actually "complete"
                DDLogDebug("\(identifier): No content to scroll (content fits in viewport), waiting \(duration)s before completion")
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    DDLogDebug("\(identifier): Completing after waiting \(duration)s for content that fits")
                    self.onScrollComplete()
                }
                return
            }

            // Cancel any existing completion handler
            completionWorkItem?.cancel()
            scrollDelayWorkItem?.cancel()

            // Reset position only if we're in continuous mode and not already at the top
            if continuousScrolling, scrollView.contentOffset.y > 5 {
                DDLogDebug("\(identifier): Resetting scroll position to top for continuous mode")
                scrollView.setContentOffset(.zero, animated: false)

                // Add a small delay to ensure UI updates before starting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak scrollView] in
                    guard let self, let scrollView, !self.isAnimating else {
                        return
                    }

                    performScrollAnimation(scrollView: scrollView, duration: duration, scrollableAmount: scrollableAmount, identifier: identifier)
                }
                return
            }

            // Create a delay work item
            let delayItem = DispatchWorkItem { [weak self] in
                guard let self else {
                    return
                }

                performScrollAnimation(scrollView: scrollView, duration: duration, scrollableAmount: scrollableAmount, identifier: identifier)
            }

            scrollDelayWorkItem = delayItem

            // Schedule the scrolling after the specified delay
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: delayItem)
            } else {
                // Execute immediately if no delay
                delayItem.perform()
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Only check for reaching end if we're actively scrolling and not in continuous mode
            if didStartScroll, !didCompleteScroll, isAnimating, !continuousScrolling {
                let maxScrollOffset = max(0, contentHeight - viewportHeight)

                // If we've reached near the end of the scroll
                if scrollView.contentOffset.y >= maxScrollOffset - 5 { // Allow slight margin for rounding
                    // Complete the scroll once we're near the end
                    completionWorkItem?.cancel() // Cancel the delayed completion

                    // Create a new completion item with a shorter delay
                    let newCompletionItem = DispatchWorkItem { [weak self] in
                        guard let self, !self.didCompleteScroll else {
                            return
                        }

                        didCompleteScroll = true
                        isAnimating = false
                        onScrollComplete()
                    }

                    completionWorkItem = newCompletionItem

                    // Execute after a short delay to ensure we stay at the bottom
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: newCompletionItem)
                }
            }
        }

        /// check actual size after layout
        func checkContentSizeAfterLayout(identifier: String, scrollDuration: TimeInterval, scrollDelay: TimeInterval, continuous: Bool) {
            guard let scrollView else {
                return
            }

            // Don't check if already animating or if already started and not continuous
            if isAnimating || (didStartScroll && !continuous) {
                DDLogDebug("\(identifier): Skipping content size check - already in progress")
                return
            }

            // Get the latest measurements
            let measuredContentHeight = scrollView.contentSize.height
            let viewportHeight = scrollView.bounds.height

            // Override content height calculation for events and weather to ensure all content is visible
            let contentHeight: CGFloat
            if identifier.contains("event") {
                // Calculate expected content height for events
                let actualEventCount = eventCount ?? 34 // fallback
                let numberOfRows = max(1, (actualEventCount + 1) / 2)
                let cardHeight: CGFloat = 90
                let cardPadding: CGFloat = 40 // 20 top + 20 bottom
                let rowSpacing: CGFloat = 16
                let bottomSpacer: CGFloat = 100

                let calculatedHeight = CGFloat(numberOfRows) * (cardHeight + cardPadding) +
                    CGFloat(numberOfRows - 1) * rowSpacing +
                    bottomSpacer

                contentHeight = max(measuredContentHeight, calculatedHeight)

                // Combined log will be shown later
            } else if identifier.contains("weather") {
                // Calculate expected content height for weather
                let forecastCount = weatherForecastCount ?? 4 // fallback
                let todayCount = weatherTodayCount ?? 7 // fallback
                let totalItems = forecastCount + todayCount
                let itemHeight: CGFloat = 90 // Same as events
                let itemPadding: CGFloat = 20 // 10 top + 10 bottom for weather cards
                let rowSpacing: CGFloat = 16
                let bottomSpacer: CGFloat = 100

                let calculatedHeight = CGFloat(totalItems) * (itemHeight + itemPadding) +
                    CGFloat(max(0, totalItems - 1)) * rowSpacing +
                    bottomSpacer

                contentHeight = max(measuredContentHeight, calculatedHeight)

                // Combined log will be shown later
            } else {
                contentHeight = measuredContentHeight
            }

            // Show combined log with all relevant information
            let scrollableAmount = max(0, contentHeight - viewportHeight)
            if identifier.contains("event"), let actualEventCount = eventCount {
                let numberOfRows = max(1, (actualEventCount + 1) / 2)
                DDLogDebug("\(identifier): Events: \(actualEventCount) (\(numberOfRows) rows), Content: \(contentHeight)px, Scrollable: \(scrollableAmount)px")
            } else if identifier.contains("weather") {
                let forecastCount = weatherForecastCount ?? 4
                let todayCount = weatherTodayCount ?? 7
                let totalItems = forecastCount + todayCount
                DDLogDebug("\(identifier): Weather: \(forecastCount)F+\(todayCount)T=\(totalItems), Content: \(contentHeight)px, Scrollable: \(scrollableAmount)px")
            } else {
                DDLogDebug("\(identifier): Content: \(contentHeight)px, Viewport: \(viewportHeight)px, Scrollable: \(scrollableAmount)px")
            }

            // Update stored values
            self.contentHeight = contentHeight
            self.viewportHeight = viewportHeight

            // Increment counter
            contentSizeCheckCounter += 1

            // Only declare content fits if we've checked multiple times and it still fits
            // This helps avoid false positives from incomplete layout
            if contentHeight <= viewportHeight {
                if contentSizeCheckCounter >= maxContentSizeChecks {
                    // After multiple checks, if content still appears to fit, we'll accept it
                    didCompleteScroll = !continuous // In continuous mode, we never actually "complete"
                    DDLogDebug("\(identifier): Content confirmed to fit viewport after \(contentSizeCheckCounter) checks, waiting \(scrollDuration)s before completion")
                    DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration) { [weak self] in
                        guard let self, self.scrollView != nil else {
                            return
                        }

                        onScrollComplete()
                    }
                } else {
                    // Schedule another check - content size might still be updating
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.checkContentSizeAfterLayout(
                            identifier: identifier,
                            scrollDuration: scrollDuration,
                            scrollDelay: scrollDelay,
                            continuous: continuous
                        )
                    }
                }
                return
            }

            // Content doesn't fit, start scrolling only if not already started
            if contentHeight > viewportHeight, !didStartScroll || continuous {
                startSmoothScrolling(
                    duration: scrollDuration,
                    delay: scrollDelay,
                    identifier: identifier
                )
            }
        }

        // MARK: Private

        private func performScrollAnimation(scrollView: UIScrollView, duration: TimeInterval, scrollableAmount: CGFloat, identifier: String) {
            isAnimating = true
            let currentOffset = scrollView.contentOffset.y

            // Calculate the maximum possible scroll offset to ensure all content is visible
            let maxContentOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let finalScrollAmount = min(scrollableAmount, maxContentOffset)

            DDLogDebug("\(identifier): Scrolling \(finalScrollAmount - currentOffset)px over \(duration)s")

            // Use a slow, smooth animation for tvOS
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveLinear, .allowUserInteraction, .beginFromCurrentState],
                animations: {
                    scrollView.contentOffset = CGPoint(x: 0, y: finalScrollAmount)
                }
            ) { [weak self] completed in
                guard let self, completed else {
                    DDLogDebug("\(identifier): Animation incomplete or coordinator deallocated")
                    return
                }

                if continuousScrolling {
                    // In continuous mode, increment cycle count
                    cycleCount += 1
                    DDLogDebug("\(identifier): Completed scroll cycle \(cycleCount)")

                    // Call completion after every cycle (will trigger parent's callback)
                    onScrollComplete()

                    // Reset state for next cycle after a pause
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self, weak scrollView] in
                        guard let self, let scrollView else {
                            return
                        }

                        // Reset state for next cycle
                        isAnimating = false
                        didStartScroll = false // Allow restart for continuous mode

                        DDLogDebug("\(identifier): Resetting scroll position to top")
                        scrollView.setContentOffset(.zero, animated: false)

                        // Verify reset and start next cycle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak scrollView] in
                            guard let self, let scrollView else {
                                return
                            }

                            // Double-check position
                            if scrollView.contentOffset.y > 5 {
                                DDLogDebug("\(identifier): Scroll position not properly reset, forcing to top")
                                scrollView.setContentOffset(.zero, animated: false)
                            }

                            // Start next cycle
                            startSmoothScrolling(
                                duration: duration,
                                delay: 0,
                                identifier: identifier
                            )
                        }
                    }
                } else {
                    // In regular mode, just complete once
                    if !didCompleteScroll {
                        didCompleteScroll = true
                        isAnimating = false
                        DDLogDebug("\(identifier): Scroll animation complete, firing callback")
                        onScrollComplete()
                    }
                }
            }
        }
    }

    let content: Content
    let onScrollComplete: () -> Void
    let scrollDuration: TimeInterval
    let scrollDelay: TimeInterval
    let identifier: String
    let hasLessThanThreeEvent: Bool
    let continuousScrolling: Bool
    let eventCount: Int?
    let weatherForecastCount: Int?
    let weatherTodayCount: Int?

    static func dismantleUIView(_: UIScrollView, coordinator: Coordinator) {
        // Ensure all animations are properly cancelled and state is reset
        coordinator.cancelScrolling()
        coordinator.didStartScroll = false
        coordinator.didCompleteScroll = false
        coordinator.isAnimating = false
        coordinator.cycleCount = 0
        coordinator.scrollView = nil
        coordinator.hostingController = nil
    }

    func makeUIView(context: Context) -> UIScrollView {
        // Create the scroll view
        let scrollView = OptimizedScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator
        scrollView.accessibilityIdentifier = identifier

        // Create a hosting controller for the SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear

        // Add the content to the scroll view
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostingController.view)

        // Configure constraints for the content
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        ])

        // Conditional width constraint
        if hasLessThanThreeEvent {
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        } else if #available(tvOS 16.0, *) {
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        } else {
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: 75).isActive = true
        }

        // Store the hosting controller to prevent it from being deallocated
        context.coordinator.hostingController = hostingController

        // Save reference to scroll view in coordinator
        context.coordinator.scrollView = scrollView
        context.coordinator.continuousScrolling = continuousScrolling
        context.coordinator.eventCount = eventCount
        context.coordinator.weatherForecastCount = weatherForecastCount
        context.coordinator.weatherTodayCount = weatherTodayCount

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update the content
        context.coordinator.hostingController?.rootView = content

        // Update continuous scrolling flag
        context.coordinator.continuousScrolling = continuousScrolling
        context.coordinator.eventCount = eventCount

        // MODIFIED: Allow more time for layout to complete before checking content size
        DispatchQueue.main.async { [weak scrollView] in
            guard let scrollView else {
                return
            }

            // Force layout to update completely
            scrollView.layoutIfNeeded()

            // Reset counters
            context.coordinator.contentSizeCheckCounter = 0

            // If we're switching to continuous mode and already started scrolling
            if continuousScrolling, context.coordinator.didStartScroll, !context.coordinator.isAnimating {
                // Reset and restart in continuous mode
                context.coordinator.didCompleteScroll = false
                context.coordinator.didStartScroll = false
            }

            // Schedule first content size check with a delay to ensure layout is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.checkContentSizeAfterLayout(
                    identifier: identifier,
                    scrollDuration: scrollDuration,
                    scrollDelay: scrollDelay,
                    continuous: continuousScrolling
                )
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScrollComplete: onScrollComplete)
    }
}
