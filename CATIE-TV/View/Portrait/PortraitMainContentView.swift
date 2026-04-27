//
//  PortraitMainContentView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import SwiftUI

// MARK: - PortraitMainContentView

struct PortraitMainContentView: View {
    // MARK: - Properties

    /// The view model containing data to display
    let viewModel: PortraitViewModel

    /// Theme for styling
    let theme: PortraitTheme

    /// Whether to display events or weather information
    @Binding var showingEvents: Bool

    /// Number of events per page
    let eventsPerPage: Int

    /// Number of status indicators per page
    let statusPerPage: Int

    // MARK: - State

    /// State to control view transitions
    @State private var isInitialAppearance: Bool = true

    /// State to track if we're currently in a scrolling operation
    @State private var isScrolling: Bool = false

    /// State to track when the next view switch is allowed
    @State private var nextSwitchAllowedAfter: Date = .init()

    /// Controls which content is actually shown
    @State private var actuallyShowingEvents: Bool = true

    /// Keeps track of the desired view (what we'll switch to when allowed)
    @State private var desiredShowingEvents: Bool = true

    // MARK: - Constants

    /// Minimum time between view switches (prevents rapid back-and-forth)
    private let minimumSwitchInterval: TimeInterval = 30.0

    /// Scroll cool down period (time after completing a scroll before allowing a switch)
    private let scrollCompletionDelay: TimeInterval = 1.0

    // MARK: - Callbacks

    /// Called when all activities have been shown
    var onAllActivitiesShown: (() -> Void)?

    /// Called when all weather items have been shown
    var onAllWeatherShown: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Main image/carousel
            PortraitCarouselView(
                currentImage: viewModel.currentCarouselImage,
                hasAudio: viewModel.currentCarouselHasAudio,
                isNarrationPlaying: viewModel.isNarrationPlaying,
                uiType: viewModel.uiType,
                theme: theme
            )
            .accessibilityIdentifier("portraitCarouselView")

            // Status indicators (if needed)
            if !viewModel.statusIndicatorArray.isEmpty {
                PortraitStatusIndicatorView(
                    indicators: viewModel.statusIndicatorArray,
                    theme: theme,
                    statusPerPage: statusPerPage
                )
                .accessibilityIdentifier("portraitStatusIndicatorView")
            } else {
                // Empty state for status indicators with the same dimensions
                statusIndicatorEmptyView
                    .accessibilityIdentifier("portraitStatusIndicatorEmptyView")
            }

            // Content section - handle empty states appropriately
            Group {
                if hasEventsToShow {
                    // Events view
                    PortraitEventsView(
                        events: viewModel.eventListArray,
                        theme: theme,
                        onAllEventsShown: handleEventsShown
                    )
                    .accessibilityIdentifier("portraitEventsView")
                    .transition(.opacity)
                    .contentShape(Rectangle())
                    .frame(height: 552)
                } else if hasWeatherToShow {
                    // Weather view
                    PortraitWeatherView(
                        forecastArray: viewModel.forecastWeatherArray,
                        todayWeatherArray: viewModel.todayWeatherArray,
                        theme: theme,
                        onAllWeatherShown: handleWeatherShown,
                        eventsAvailable: !viewModel.eventListArray.isEmpty
                    )
                    .accessibilityIdentifier("portraitWeatherView")
                    .transition(.opacity)
                    .contentShape(Rectangle())
                    .frame(height: 552)
                } else {
                    // No content available - show empty state
                    emptyContentView
                        .accessibilityIdentifier("portraitEmptyContentView")
                        .transition(.opacity)
                        .contentShape(Rectangle())
                        .frame(height: 552)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: actuallyShowingEvents)
            .animation(.easeInOut(duration: 0.5), value: viewModel.eventListArray.isEmpty)
            .animation(.easeInOut(duration: 0.5), value: viewModel.forecastWeatherArray.isEmpty)
            .accessibilityIdentifier("contentToggleContainer")
        }
        .frame(width: UIScreen.main.bounds.width * 0.47 + 20)
        .accessibilityIdentifier("portraitMainContentStack")
        // Handle initial appearance
        .onAppear {
            if isInitialAppearance {
                isInitialAppearance = false

                // Initialize both states to the binding value
                actuallyShowingEvents = showingEvents
                desiredShowingEvents = showingEvents

                // Check if we should auto-switch to weather immediately
                if shouldAutoSwitchToWeather {
                    DDLogDebug("PortraitMainContentView : Initial switch to weather view due to empty events list")
                    // Update both the actual and desired states
                    actuallyShowingEvents = false
                    desiredShowingEvents = false
                    showingEvents = false
                }
            }
        }
        // Monitor changes to the external binding
        .onChange(of: showingEvents) { newValue in
            // Update our desired state, but don't change the view yet
            desiredShowingEvents = newValue
            attemptViewSwitch()
        }
        // Handle changes in data after initial appearance
        .onChange(of: viewModel.eventListArray.isEmpty) { isEmpty in
            if !isInitialAppearance, isEmpty, !viewModel.forecastWeatherArray.isEmpty, actuallyShowingEvents {
                // Auto-switch to weather if events become empty after initial load
                DDLogDebug("PortraitMainContentView : Auto-switching to weather view due to events becoming empty")

                // Update the desired state
                desiredShowingEvents = false
                attemptViewSwitch()
            }
        }
    }

    // MARK: - Helper Methods

    /// Handles completion of events scrolling
    private func handleEventsShown() {
        // Mark scrolling as complete
        isScrolling = false

        // After a delay, switch to weather if that was requested
        DispatchQueue.main.asyncAfter(deadline: .now() + scrollCompletionDelay) {
            // Only switch if we're still showing events
            if actuallyShowingEvents {
                // Allow the original callback to proceed
                onAllActivitiesShown?()

                // Update the desired state to show weather
                desiredShowingEvents = false

                // Attempt to switch views
                attemptViewSwitch()
            }
        }
    }

    /// Handles completion of weather scrolling
    private func handleWeatherShown() {
        // Mark scrolling as complete
        isScrolling = false

        // After a delay, switch to events if that was requested
        DispatchQueue.main.asyncAfter(deadline: .now() + scrollCompletionDelay) {
            // Only switch if we're still showing weather
            if !actuallyShowingEvents {
                // Allow the original callback to proceed
                onAllWeatherShown?()

                // Update the desired state to show events
                desiredShowingEvents = true

                // Attempt to switch views
                attemptViewSwitch()
            }
        }
    }

    /// Attempts to switch views if conditions allow
    private func attemptViewSwitch() {
        // Early return if we're already showing the desired view
        if actuallyShowingEvents == desiredShowingEvents {
            return
        }

        // Don't switch if scrolling is in progress
        if isScrolling {
            DDLogDebug("PortraitMainContentView: View switch requested but scrolling is in progress")
            return
        }

        // Don't switch if we haven't waited long enough since the last switch
        let now = Date()
        if now < nextSwitchAllowedAfter {
            let remainingTime = nextSwitchAllowedAfter.timeIntervalSince(now)

            // Schedule a delayed check to switch after the cooldown
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime + 0.1) {
                attemptViewSwitch()
            }
            return
        }

        // If we get here, we can switch views
        DDLogDebug("PortraitMainContentView: Switching views from \(actuallyShowingEvents ? "events" : "weather") to \(desiredShowingEvents ? "events" : "weather")")

        // Mark that scrolling is about to begin
        isScrolling = true

        // Update the next allowed switch time
        nextSwitchAllowedAfter = now.addingTimeInterval(minimumSwitchInterval)

        // Perform the view switch with animation
        withAnimation {
            actuallyShowingEvents = desiredShowingEvents

            // Also update the binding to keep them in sync
            showingEvents = desiredShowingEvents
        }
    }

    // MARK: - Computed Properties

    /// Determines if we should show the events view
    private var hasEventsToShow: Bool {
        actuallyShowingEvents && !viewModel.eventListArray.isEmpty
    }

    /// Determines if we should show the weather view
    private var hasWeatherToShow: Bool {
        // Make this mutually exclusive with hasEventsToShow by checking !hasEventsToShow first
        !hasEventsToShow && !viewModel.forecastWeatherArray.isEmpty
    }

    /// Determines if we should auto-switch to weather view on initial load
    private var shouldAutoSwitchToWeather: Bool {
        viewModel.eventListArray.isEmpty && !viewModel.forecastWeatherArray.isEmpty && showingEvents
    }

    // MARK: - Empty Content View

    /// View to display when no content is available
    private var emptyContentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(theme.primaryText.opacity(0.5))

            Text("No Activities or Weather")
                .font(.custom("Poppins-Bold", size: 24))
                .foregroundColor(theme.primaryText)

            Text("There are currently no activities or weather forecasts to display.")
                .font(.custom("Poppins-Regular", size: 18))
                .foregroundColor(theme.primaryText.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityIdentifier("portraitEmptyContentText")
        }
        .frame(maxWidth: .infinity, maxHeight: 512) // Same height as the content areas
        .padding()
        .background(.clear)
        .cornerRadius(15)
        .shadow(color: theme.cardShadow, radius: 4, x: 0, y: 2)
        .padding()
        .accessibilityIdentifier("portraitEmptyContentContainer")
    }

    // MARK: - Empty Status Indicator View

    /// View to display when no status indicators are available
    private var statusIndicatorEmptyView: some View {
        VStack(spacing: 0) {
            Text("Status Indicator")
                .font(.custom("Poppins-Bold", size: 24))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .accessibilityIdentifier("statusIndicatorEmptyHeaderText")

            VStack(spacing: 15) {
                Image(systemName: "info.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(theme.primaryText.opacity(0.5))

                Text("No Status Indicators")
                    .font(.custom("Poppins-Medium", size: 20))
                    .foregroundColor(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("statusIndicatorEmptyTitle")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .padding(.bottom, 15)
            .accessibilityIdentifier("statusIndicatorEmptyContent")
        }
        .accessibilityIdentifier("statusIndicatorEmptyContainer")
    }
}

// MARK: - Preview

#if DEBUG
    struct PortraitMainContentView_Previews: PreviewProvider {
        static var previews: some View {
            let theme = PortraitTheme(colorScheme: .light)

            PortraitMainContentView(
                viewModel: PortraitViewModel(),
                theme: theme,
                showingEvents: .constant(true),
                eventsPerPage: 8,
                statusPerPage: 4
            )
            .previewLayout(.fixed(width: 600, height: 800))
        }
    }
#endif
