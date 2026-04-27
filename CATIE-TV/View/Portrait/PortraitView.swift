//
//  PortraitView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import AVKit
import CocoaLumberjackSwift
import SwiftUI

// MARK: - PortraitView

struct PortraitView: View {
    // MARK: - Properties

    @ObservedObject var viewModel: PortraitViewModel
    @State private var showingEvents: Bool = true
    @State private var contentSwitchTimer: Timer?
    @Environment(\.colorScheme) var colorScheme

    private let eventsPerPage = 8
    private let statusPerPage = 4

    /// Short delay between content view transitions
    private let transitionDelay: TimeInterval = 2.0

    private var theme: PortraitTheme {
        PortraitTheme(colorScheme: colorScheme)
    }

    // MARK: - Main View

    var body: some View {
        ZStack {
            // Background layer
            backgroundContent
                .edgesIgnoringSafeArea(.all)

            // Main content layout
            VStack(spacing: 0) {
                // Empty header space
                Rectangle()
                    .opacity(0)
                    .frame(height: viewModel.uiType == 4 || viewModel.uiType == 6 ? 0 : 150)

                // Main content area
                if viewModel.uiType == 3 {
                    PortraitMainContentView(
                        viewModel: viewModel,
                        theme: theme,
                        showingEvents: $showingEvents,
                        eventsPerPage: eventsPerPage,
                        statusPerPage: statusPerPage,
                        onAllActivitiesShown: { handleAllActivitiesShown() },
                        onAllWeatherShown: { handleAllWeatherShown() }
                    )
                    .accessibilityIdentifier("portraitMainContent")
                    .onAppear { setupContentCallbacks() }
                    .onDisappear {
                        contentSwitchTimer?.invalidate()
                        contentSwitchTimer = nil
                        contentSwitchTimer = nil
                    }
                } else if viewModel.uiType == 4 {
                    // UI Type 4: Carousel fitted in content area (between header and footer)
                    PortraitCarouselView(
                        currentImage: viewModel.currentCarouselImage,
                        hasAudio: viewModel.currentCarouselHasAudio,
                        isNarrationPlaying: viewModel.isNarrationPlaying,
                        uiType: viewModel.uiType,
                        theme: theme
                    )
                    .accessibilityIdentifier("portraitContentCarousel")
                } else if viewModel.uiType == 6 {
                    // UI Type 6: Padded carousel in content area with safe area respect
                    GeometryReader { geometry in
                        PortraitCarouselView(
                            currentImage: viewModel.currentCarouselImage,
                            hasAudio: viewModel.currentCarouselHasAudio,
                            isNarrationPlaying: viewModel.isNarrationPlaying,
                            uiType: viewModel.uiType,
                            theme: theme
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .accessibilityIdentifier("portraitPaddedCarousel")
                    }
                } else {
                    Spacer()
                        .accessibilityIdentifier("portraitMainContentSpacer")
                }

                // Empty footer space
                Rectangle()
                    .opacity(0)
                    .frame(height: viewModel.uiType == 4 || viewModel.uiType == 6 ? 0 : 115)
            }
            .focusable(true)
            .contentShape(Rectangle())
            .edgesIgnoringSafeArea(.all)
            .accessibilityIdentifier("portraitContentContainer")

            // Sara Alert overlay (full screen, behind header/footer)
            PortraitSaraAlertOverlay(
                isSaraAlertPresented: viewModel.isSaraAlertPresented,
                saraAlertHeader: viewModel.saraAlertHeader,
                saraAlertMessage: viewModel.saraAlertMessage,
                saraAlertFooter: viewModel.saraAlertFooter,
                saraAlertBorderColor: viewModel.saraAlertBorderColor,
                saraAlertBorderWidth: viewModel.saraAlertBorderWidth,
                saraAlertBodyBackgroundColor: viewModel.saraAlertBodyBackgroundColor,
                saraAlertBodyTextColor: viewModel.saraAlertBodyTextColor,
                saraAlertFooterBackgroundColor: viewModel.saraAlertFooterBackgroundColor,
                saraAlertFooterTextColor: viewModel.saraAlertFooterTextColor,
                saraAlertHeaderFontSize: viewModel.saraAlertHeaderFontSize,
                saraAlertHeaderFontStyle: viewModel.saraAlertHeaderFontStyle,
                saraAlertFooterFontSize: viewModel.saraAlertFooterFontSize,
                saraAlertFooterFontStyle: viewModel.saraAlertFooterFontStyle,
                saraAlertBodyFontSize: viewModel.saraAlertBodyFontSize,
                saraAlertHasRichText: viewModel.saraAlertHasRichText,
                saraAlertBodyTextComponents: viewModel.saraAlertBodyTextComponents,
                saraAlertFlashing: viewModel.saraAlertFlashing,
                saraAlertFlashColor: viewModel.saraAlertFlashColor
            )
            .allowsHitTesting(false)
            .edgesIgnoringSafeArea(.all)
            .accessibilityIdentifier("portraitSaraAlertContainer")

            // Header and Footer overlay (always on top)

            VStack(spacing: 0) {
                PortraitHeaderView(
                    headerTime: viewModel.headerTime,
                    headerDate: viewModel.headerDate,
                    temperature: viewModel.temperature,
                    location: viewModel.location,
                    weatherIcon: viewModel.weatherIcon,
                    siteLogo: viewModel.siteLogo,
                    theme: theme
                )
                .zIndex(10)

                Spacer()

                PortraitFooterView(
                    scrollableText: viewModel.scrollableText,
                    isRadioPlaying: viewModel.isRadioPlaying,
                    isNetworkDown: viewModel.isNetworkDown,
                    theme: theme,
                    uiType: viewModel.uiType,
                    tvRadioFlag: viewModel.tvRadioFlag
                )
                .zIndex(10)
                .accessibilityIdentifier("portraitFooter")
            }
            .frame(width: UIScreen.main.bounds.height, height: UIScreen.main.bounds.width)
            .allowsHitTesting(false)
            .accessibilityIdentifier("portraitMainStack")
            .edgesIgnoringSafeArea(.all)

            PortraitClockView(
                message: viewModel.clockMessage,
                customFontName: viewModel.customFontName,
                customFontSize: CGFloat(Double(viewModel.customFontSize) ?? 100),
                isVisible: viewModel.isClockVisible,
                isSaraAlertPresented: viewModel.isSaraAlertPresented
            )
            .allowsHitTesting(false)
            .edgesIgnoringSafeArea(.all)
            .accessibilityIdentifier("portraitClockContainer")

            if viewModel.isLoading {
                PortraitLoadingOverlay()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(100) // Ensure it's above everything else
            }

            RegistrationTapHandler(onRegistrationTaps: handleRegistrationTap)
                .allowsHitTesting(true)
                .accessibilityIdentifier("registrationTapHandler")
        }
        .frame(width: UIScreen.main.bounds.height, height: UIScreen.main.bounds.width)
        .accessibilityIdentifier("portraitViewRoot")
    }

    // MARK: - Background Content

    private var backgroundContent: some View {
        Group {
            if viewModel.uiType == 3 || viewModel.uiType == 6 || viewModel.uiType == 4 {
                Image("MainScreenBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                    .rotationEffect(.degrees(90))
                    .frame(width: UIScreen.main.bounds.height, height: UIScreen.main.bounds.width)
                    .accessibilityIdentifier("portraitBackgroundImage")
            } else {
                PortraitCarouselView(
                    currentImage: viewModel.currentCarouselImage,
                    hasAudio: viewModel.currentCarouselHasAudio,
                    isNarrationPlaying: viewModel.isNarrationPlaying,
                    uiType: viewModel.uiType,
                    theme: theme
                )
                .accessibilityIdentifier("portraitFullscreenCarousel")
            }
        }
        .accessibilityIdentifier("portraitBackground")
    }

    // MARK: - Registration Tap Handler

    private func handleRegistrationTap() {
        DDLogDebug("PortraitView : Registration tap detected")
        guard let mainVC = viewModel.mainViewController else {
            DDLogDebug("PortraitView : Main view controller not available - cannot present registration page")
            return
        }

        DDLogDebug("PortraitView : Presenting registration page")
        mainVC.presentRegistrationPage()
    }

    // MARK: - Content Switching

    /// Handle the event when all activities have been shown
    private func handleAllActivitiesShown() {
        DDLogDebug("PortraitView: handleAllActivitiesShown called - showingEvents: \(showingEvents)")

        // Cancel any existing timers to prevent multiple transitions
        contentSwitchTimer?.invalidate()
        contentSwitchTimer = nil

        // Only switch if we're currently showing events
        if showingEvents {
            DDLogDebug("PortraitView: Scheduling switch from events to weather after \(transitionDelay)s delay")
            // Switch to weather view after a short delay
            contentSwitchTimer = Timer.scheduledTimer(withTimeInterval: transitionDelay, repeats: false) { _ in
                DDLogDebug("PortraitView: Timer fired - switching from events to weather")
                withAnimation {
                    showingEvents = false
                }
            }
        } else {
            DDLogDebug("PortraitView: Already showing weather, ignoring handleAllActivitiesShown")
        }
    }

    /// Handle the event when all weather content has been shown
    private func handleAllWeatherShown() {
        DDLogDebug("PortraitView: handleAllWeatherShown called - showingEvents: \(showingEvents)")

        // Cancel any existing timers to prevent multiple transitions
        contentSwitchTimer?.invalidate()
        contentSwitchTimer = nil

        // Only switch if we're currently showing weather
        if !showingEvents {
            DDLogDebug("PortraitView: Scheduling switch from weather to events after \(transitionDelay)s delay")
            // Switch back to events view after a short delay
            contentSwitchTimer = Timer.scheduledTimer(withTimeInterval: transitionDelay, repeats: false) { _ in
                DDLogDebug("PortraitView: Timer fired - switching from weather to events")
                withAnimation {
                    showingEvents = true
                }
            }
        } else {
            DDLogDebug("PortraitView: Already showing events, ignoring handleAllWeatherShown")
        }
    }

    /// Set up content switch callbacks for the first time
    private func setupContentCallbacks() {
        DDLogDebug("PortraitView : Setting up content switch callbacks")

        // If we're starting with events, we don't need to do anything special
        if showingEvents {
            DDLogDebug("PortraitView : Starting with events view")
        } else {
            // If we're starting with weather, set up a timer to switch back to events
            DDLogDebug("PortraitView : Starting with weather view")
        }
    }
}

// MARK: - Preview

#if DEBUG
    struct PortraitView_Previews: PreviewProvider {
        static var previews: some View {
            let vmNormal = PortraitViewModel()
            vmNormal.uiType = 3
            let vmCarousel = PortraitViewModel()
            vmCarousel.uiType = 4
            let vmPaddedWithRadio = PortraitViewModel()
            vmPaddedWithRadio.uiType = 6
            vmPaddedWithRadio.tvRadioFlag = 1
            let vmPaddedNoRadio = PortraitViewModel()
            vmPaddedNoRadio.uiType = 6
            vmPaddedNoRadio.tvRadioFlag = 0

            return Group {
                PortraitView(viewModel: vmNormal)
                    .previewDisplayName("Normal Layout")
                PortraitView(viewModel: vmCarousel)
                    .previewDisplayName("Full Carousel")
                PortraitView(viewModel: vmPaddedWithRadio)
                    .previewDisplayName("Padded with Radio")
                PortraitView(viewModel: vmPaddedNoRadio)
                    .previewDisplayName("Padded without Radio")
                PortraitView(viewModel: vmNormal)
                    .environment(\.colorScheme, .dark)
                    .previewDisplayName("Dark Mode")
            }
            .previewLayout(.fixed(width: 1080, height: 1920))
        }
    }
#endif
