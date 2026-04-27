//
//  PortraitEventsView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import SwiftUI

// MARK: - EventCardContainer

struct EventCardContainer: View {
    let event: (String, String, String, String, String, Bool)
    let theme: PortraitTheme

    var body: some View {
        EventCard(
            time: event.0,
            title: event.2,
            description: event.4,
            isActive: event.5,
            theme: theme
        )
        .accessibilityIdentifier("eventCardContent")
    }
}

// MARK: - EventCard

struct EventCard: View {
    let time: String
    let title: String
    let description: String
    let isActive: Bool
    let theme: PortraitTheme

    var body: some View {
        HStack(spacing: 0) {
            // Left side with time text
            Text(time)
                .font(.custom("Poppins-Medium", size: 24))
                .foregroundColor(.white)
                .frame(width: 120, alignment: .leading)
                .accessibilityIdentifier("eventTimeText")

            Divider()
                .background(Color.white)
                .accessibilityIdentifier("eventDivider")
            Spacer().frame(width: 16)

            // Right side with title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Poppins-Bold", size: 20))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .accessibilityIdentifier("eventTitleText")

                Text(description)
                    .font(.custom("Poppins-Regular", size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .accessibilityIdentifier("eventDescriptionText")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("eventDetailsContainer")
        }
        .padding(20)
        .frame(height: 90) // Fixed height for the card
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    isActive
                        ? theme.activeEventGradientStart
                        : theme.eventGradientStart,
                    isActive
                        ? theme.activeEventGradientEnd
                        : theme.eventGradientEnd,
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(15)
        .shadow(color: theme.cardShadow, radius: 6, x: 0, y: 3)
        .accessibilityIdentifier(isActive ? "activeEventCard" : "inactiveEventCard")
    }
}

// MARK: - EventsGridView

struct EventsGridView: View {
    // MARK: Internal

    let events: [(String, String, String, String, String, Bool)]
    let theme: PortraitTheme
    let viewportWidth: CGFloat
    let rowSpacing: CGFloat

    var body: some View {
        VStack(spacing: rowSpacing) {
            // Group events into pairs for a two-column layout
            ForEach(0 ..< (events.count + 1) / 2, id: \.self) { rowIndex in
                eventRow(rowIndex: rowIndex)
            }
            Color.clear.frame(height: 100) // Spacer at the bottom
        }
    }

    // MARK: Private

    private var cardWidth: CGFloat {
        (viewportWidth - 35 - rowSpacing) / 2
    }

    @ViewBuilder
    private func eventRow(rowIndex: Int) -> some View {
        HStack(spacing: rowSpacing * 2) {
            // Left card in the row
            let leftIndex = rowIndex * 2
            if leftIndex < events.count {
                EventCardContainer(
                    event: events[leftIndex],
                    theme: theme
                )
                .frame(width: cardWidth)
            } else {
                // Spacer to maintain layout balance if no left card
                Spacer().frame(width: cardWidth)
            }

            // Right card in the row
            let rightIndex = rowIndex * 2 + 1
            if rightIndex < events.count {
                EventCardContainer(
                    event: events[rightIndex],
                    theme: theme
                )
                .frame(width: cardWidth)
            } else {
                // Spacer to maintain layout balance if no right card
                Spacer().frame(width: cardWidth)
            }
        }
    }
}

// MARK: - PortraitEventsView

struct PortraitEventsView: View {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        events: [(String, String, String, String, String, Bool)],
        theme: PortraitTheme,
        onAllEventsShown: (() -> Void)? = nil
    ) {
        self.events = events
        self.theme = theme
        self.onAllEventsShown = onAllEventsShown
    }

    // MARK: Internal

    /// Event data from parent
    let events: [(String, String, String, String, String, Bool)]

    /// Theme to use for styling
    let theme: PortraitTheme

    /// Callback when all events have been shown
    var onAllEventsShown: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Text("Activities")
                .font(.custom("Poppins-Bold", size: 24))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .accessibilityIdentifier("activitiesHeaderText")

            // Use GeometryReader to get the available width
            GeometryReader { geometry in
                // Custom scroll view with optimized auto-scrolling
                AutoScrollingScrollView(
                    identifier: "eventScrollView",
                    scrollDuration: ScrollDurationCalculator.calculateEventsDuration(for: events.count),
                    scrollDelay: 3,
                    onScrollComplete: {
                        DDLogDebug("PortraitEventsView: onScrollComplete fired from AutoScrollingScrollView - hasShownAllEvents: \(hasShownAllEvents)")
                        if !hasShownAllEvents {
                            hasShownAllEvents = true
                            DDLogDebug("PortraitEventsView: Completed events display cycle - triggering callback")
                            onAllEventsShown?()
                        } else {
                            DDLogDebug("PortraitEventsView: onScrollComplete fired but hasShownAllEvents is already true - ignoring")
                        }
                    },
                    hasLessThanThreeEvent: events.count < 3,
                    eventCount: events.count,
                ) {
                    EventsGridView(
                        events: events,
                        theme: theme,
                        viewportWidth: geometry.size.width,
                        rowSpacing: rowSpacing
                    )
                }
                .id(viewID) // Force view recreation on content changes
            }
            .frame(height: 512)
        }
        .accessibilityIdentifier("portraitEventsView")
        .onAppear {
            hasShownAllEvents = false
        }
        .onChange(of: events.count) { newCount in
            // Reset when events count changes
            DDLogDebug("PortraitEventsView: Events count changed to \(newCount)")
            hasShownAllEvents = false
            // Add small delay to prevent rapid view recreation during orientation changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewID = UUID() // Force view recreation to restart scroll
            }
        }
        .onChange(of: eventsContentHash) { _ in
            // Detect any change in events array content - including time changes
            DDLogDebug("PortraitEventsView: Events content changed")
            hasShownAllEvents = false
            // Add small delay to prevent rapid view recreation during orientation changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewID = UUID() // Force view recreation to restart scroll
            }
        }
    }

    // MARK: Private

    // MARK: - State

    /// Tracks if the callback has been triggered
    @State private var hasShownAllEvents = false

    /// ID for view regeneration
    @State private var viewID = UUID()

    // MARK: - Constants

    /// Spacing between rows
    private let rowSpacing: CGFloat = 16.0

    /// Creates a hash of the events content to detect changes
    private var eventsContentHash: Int {
        var hasher = Hasher()
        for event in events {
            hasher.combine(event.0) // Start time
            hasher.combine(event.1) // End time
            hasher.combine(event.2) // Event name
            hasher.combine(event.3) // Calendar name
            hasher.combine(event.4) // Description
            hasher.combine(event.5) // Active state
        }
        return hasher.finalize()
    }
}
