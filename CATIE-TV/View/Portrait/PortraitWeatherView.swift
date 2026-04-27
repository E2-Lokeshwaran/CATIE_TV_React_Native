//
//  PortraitWeatherView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import SwiftUI

// MARK: - TodayWeatherDetailCard

struct TodayWeatherDetailCard: View {
    let label: String
    let value: String
    let theme: PortraitTheme
    let index: Int

    var body: some View {
        HStack {
            // Left side with label
            Text(label)
                .font(.custom("Poppins-Medium", size: 20))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .accessibilityIdentifier("todayWeatherLabel\(index)")

            // Right side with value
            Text(value)
                .font(.custom("Poppins-Bold", size: 20))
                .foregroundColor(.white)
                .frame(width: 120, alignment: .trailing)
                .padding(.trailing, 16)
                .accessibilityIdentifier("todayWeatherValue\(index)")
        }
        .padding(10)
        .frame(height: 90)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    theme.weatherGradientStart,
                    theme.weatherGradientEnd,
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(15)
        .shadow(color: theme.cardShadow, radius: 6, x: 0, y: 3)
        .accessibilityIdentifier("todayWeatherDetailCard\(index)")
    }
}

// MARK: - WeatherCardContainer

struct WeatherCardContainer: View {
    let forecast: (String, String, String, UIImage, String)
    let theme: PortraitTheme
    let index: Int

    var body: some View {
        WeatherCard(
            day: forecast.0,
            icon: forecast.3,
            temperature: forecast.1,
            description: forecast.4,
            theme: theme,
            index: index
        )
        .accessibilityIdentifier("weatherCardContent\(index)")
    }
}

// MARK: - WeatherCard

/// Individual weather card
struct WeatherCard: View {
    let day: String
    let icon: UIImage
    let temperature: String
    let description: String
    let theme: PortraitTheme
    let index: Int

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Title bar with day
            Text(day)
                .font(.custom("Poppins-Medium", size: 24))
                .foregroundColor(.white)
                .frame(width: 120, alignment: .leading)
                .accessibilityIdentifier("weatherDayText\(index)")

            Divider()
                .background(Color.white)
                .accessibilityIdentifier("weatherDivider\(index)")

            Spacer().frame(width: 16)

            // Weather icon centered on left side
            Image(uiImage: icon.withRenderingMode(.alwaysTemplate))
                .resizable()
                .scaledToFit()
                .frame(width: 55, height: 55)
                .foregroundColor(.white)
                .accessibilityIdentifier("weatherIcon\(index)")

            Spacer()

            // Description text aligned to the right
            VStack {
                Text(temperature)
                    .font(.custom("Poppins-Bold", size: 36))
                    .foregroundColor(.white)
                    .padding(.trailing, 20)
                    .accessibilityIdentifier("weatherTemperature\(index)")

                Text(description)
                    .font(.custom("Poppins-Regular", size: 16))
                    .foregroundColor(.white)
                    .accessibilityIdentifier("weatherDescription\(index)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("weatherDetailsContainer\(index)")
        }
        .padding(20)
        .frame(height: 90)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    index == 0
                        ? theme.activeEventGradientStart
                        : theme.weatherGradientStart,
                    index == 0
                        ? theme.activeEventGradientEnd
                        : theme.weatherGradientEnd,
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(15)
        .shadow(color: theme.cardShadow, radius: 6, x: 0, y: 3)
        .accessibilityIdentifier("weatherCardContainer\(index)")
    }
}

// MARK: - CurrentConditionsView

struct CurrentConditionsView: View {
    // MARK: Internal

    let todayWeatherArray: [[String: String]]
    let theme: PortraitTheme
    let viewportWidth: CGFloat
    let rowSpacing: CGFloat

    var body: some View {
        VStack(spacing: rowSpacing) {
            // Header for today's details
            Text("Current Conditions")
                .font(.custom("Poppins-Bold", size: 18))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .accessibilityIdentifier("todayWeatherHeader")

            // Today's weather details - display in rows of 2
            ForEach(0 ..< (todayWeatherArray.count + 1) / 2, id: \.self) { rowIndex in
                currentConditionsRow(rowIndex: rowIndex)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: Private

    private var cardWidth: CGFloat {
        (viewportWidth - 35 - rowSpacing) / 2
    }

    @ViewBuilder
    private func currentConditionsRow(rowIndex: Int) -> some View {
        HStack(spacing: rowSpacing * 2) {
            // Left card
            let leftIndex = rowIndex * 2
            if leftIndex < todayWeatherArray.count {
                weatherDetailCard(at: leftIndex)
            } else {
                Spacer().frame(width: cardWidth)
            }

            // Right card
            let rightIndex = rowIndex * 2 + 1
            if rightIndex < todayWeatherArray.count {
                weatherDetailCard(at: rightIndex)
            } else {
                Spacer().frame(width: cardWidth)
            }
        }
    }

    @ViewBuilder
    private func weatherDetailCard(at index: Int) -> some View {
        let weatherDetail = todayWeatherArray[index]
        if let key = weatherDetail.keys.first, let value = weatherDetail[key] {
            TodayWeatherDetailCard(
                label: key,
                value: value,
                theme: theme,
                index: index
            )
            .frame(width: cardWidth)
        } else {
            Spacer().frame(width: cardWidth)
        }
    }
}

// MARK: - ForecastView

struct ForecastView: View {
    // MARK: Internal

    let forecastArray: [(String, String, String, UIImage, String)]
    let theme: PortraitTheme
    let viewportWidth: CGFloat
    let rowSpacing: CGFloat

    var body: some View {
        VStack(spacing: rowSpacing) {
            // Header
            Text("Forecast")
                .font(.custom("Poppins-Bold", size: 18))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .accessibilityIdentifier("forecastHeader")

            // Forecast cards in rows of 2
            ForEach(0 ..< (forecastArray.count + 1) / 2, id: \.self) { rowIndex in
                forecastRow(rowIndex: rowIndex)
            }
        }
    }

    // MARK: Private

    private var cardWidth: CGFloat {
        (viewportWidth - 35 - rowSpacing) / 2
    }

    @ViewBuilder
    private func forecastRow(rowIndex: Int) -> some View {
        HStack(spacing: rowSpacing * 2) {
            // Left card
            let leftIndex = rowIndex * 2
            if leftIndex < forecastArray.count {
                WeatherCardContainer(
                    forecast: forecastArray[leftIndex],
                    theme: theme,
                    index: leftIndex
                )
                .frame(width: cardWidth)
            } else {
                Spacer().frame(width: cardWidth)
            }

            // Right card
            let rightIndex = rowIndex * 2 + 1
            if rightIndex < forecastArray.count {
                WeatherCardContainer(
                    forecast: forecastArray[rightIndex],
                    theme: theme,
                    index: rightIndex
                )
                .frame(width: cardWidth)
            } else {
                Spacer().frame(width: cardWidth)
            }
        }
    }
}

// MARK: - WeatherContentView

struct WeatherContentView: View {
    let forecastArray: [(String, String, String, UIImage, String)]
    let todayWeatherArray: [[String: String]]
    let theme: PortraitTheme
    let viewportWidth: CGFloat
    let rowSpacing: CGFloat

    var body: some View {
        VStack(spacing: rowSpacing) {
            // Current conditions section
            if !todayWeatherArray.isEmpty {
                CurrentConditionsView(
                    todayWeatherArray: todayWeatherArray,
                    theme: theme,
                    viewportWidth: viewportWidth,
                    rowSpacing: rowSpacing
                )

                // Divider
                Divider()
                    .background(theme.primaryText.opacity(0.3))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }

            // Forecast section
            ForecastView(
                forecastArray: forecastArray,
                theme: theme,
                viewportWidth: viewportWidth,
                rowSpacing: rowSpacing
            )

            // Add extra space at the bottom to ensure adequate scrolling
            Color.clear.frame(height: 100)
        }
    }
}

// MARK: - PortraitWeatherView

struct PortraitWeatherView: View {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(
        forecastArray: [(String, String, String, UIImage, String)],
        todayWeatherArray: [[String: String]] = [],
        theme: PortraitTheme,
        onAllWeatherShown: (() -> Void)? = nil,
        eventsAvailable: Bool = true
    ) {
        self.forecastArray = forecastArray
        self.todayWeatherArray = todayWeatherArray
        self.theme = theme
        self.onAllWeatherShown = onAllWeatherShown
        self.eventsAvailable = eventsAvailable
    }

    // MARK: Internal

    /// Weather forecast data from parent
    let forecastArray: [(String, String, String, UIImage, String)]

    /// Today's weather details from parent
    let todayWeatherArray: [[String: String]]

    /// Theme to use for styling
    let theme: PortraitTheme

    /// Flag indicating whether events are available
    let eventsAvailable: Bool

    /// Callback when all weather forecasts have been shown
    var onAllWeatherShown: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Text("Weather")
                .font(.custom("Poppins-Bold", size: 24))
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .accessibilityIdentifier("weatherHeaderText")

            // Use GeometryReader to get the available width
            GeometryReader { geometry in
                // Custom scroll view with optimized auto-scrolling
                AutoScrollingScrollView(
                    identifier: "weatherScrollView",
                    scrollDuration: ScrollDurationCalculator.calculateWeatherDuration(forecastCount: forecastArray.count, todayWeatherCount: todayWeatherArray.count),
                    scrollDelay: 3,
                    continuousScrolling: !eventsAvailable,
                    // Enable continuous scrolling when no events
                    onScrollComplete: {
                        DDLogDebug(
                            "PortraitWeatherView: onScrollComplete fired from AutoScrollingScrollView - eventsAvailable: \(eventsAvailable), hasShownAllWeather: \(hasShownAllWeather)"
                        )
                        // In continuous mode, don't trigger the main view switching logic
                        if eventsAvailable,
                           !hasShownAllWeather
                        {
                            hasShownAllWeather = true
                            DDLogDebug(
                                "PortraitWeatherView: Completed weather display cycle (normal mode) - triggering callback"
                            )
                            onAllWeatherShown?()
                        } else if !eventsAvailable {
                            DDLogDebug(
                                "PortraitWeatherView: Completed weather display cycle (continuous mode) - not triggering callback"
                            )
                            // Don't call onAllWeatherShown in continuous mode to prevent view switching
                        } else {
                            DDLogDebug(
                                "PortraitWeatherView: onScrollComplete fired but hasShownAllWeather is already true - ignoring"
                            )
                        }
                    },
                    weatherForecastCount: forecastArray.count,
                    weatherTodayCount: todayWeatherArray.count
                ) {
                    WeatherContentView(
                        forecastArray: forecastArray,
                        todayWeatherArray: todayWeatherArray,
                        theme: theme,
                        viewportWidth: geometry.size.width,
                        rowSpacing: rowSpacing
                    )
                }
                .id(viewID) // Force view recreation on content changes
            }
            .frame(height: 512)
        }
        .accessibilityIdentifier("portraitWeatherView")
        .onAppear {
            hasShownAllWeather = false
            DDLogDebug("PortraitWeatherView: Appeared with eventsAvailable = \(eventsAvailable)")
        }
        .onChange(of: forecastArray.count) { newCount in
            // Reset when forecast changes
            DDLogDebug("PortraitWeatherView: Forecast count changed to \(newCount)")
            hasShownAllWeather = false
            viewID = UUID() // Force view recreation to restart scroll
        }
        .onChange(of: todayWeatherArray.count) { newCount in
            // Reset when today's weather changes
            DDLogDebug("PortraitWeatherView: Today's weather count changed to \(newCount)")
            hasShownAllWeather = false
            viewID = UUID() // Force view recreation to restart scroll
        }
        .onChange(of: eventsAvailable) { newValue in
            // Reset when events availability changes
            DDLogDebug("PortraitWeatherView: Events availability changed to \(newValue)")
            hasShownAllWeather = false
            viewID = UUID() // Force view recreation to restart scroll
        }
    }

    // MARK: Private

    // MARK: - State

    /// Tracks if the callback has been triggered
    @State private var hasShownAllWeather = false

    /// ID for view regeneration
    @State private var viewID = UUID()

    // MARK: - Constants

    /// Spacing between rows
    private let rowSpacing: CGFloat = 16.0
}

// MARK: - Preview

#if DEBUG
    struct PortraitWeatherView_Previews: PreviewProvider {
        static var theme = PortraitTheme(colorScheme: .light)

        static var sampleForecasts: [(String, String, String, UIImage, String)] = [
            ("Monday", "72°F", "Sunny", placeholderImage, "Clear day"),
            ("Tuesday", "68°F", "Partly Cloudy", placeholderImage, "Some clouds"),
            ("Wednesday", "65°F", "Cloudy", placeholderImage, "Overcast"),
            ("Thursday", "60°F", "Rain", placeholderImage, "Light rain"),
            ("Friday", "64°F", "Scattered Showers", placeholderImage, "Occasional rain"),
            ("Saturday", "70°F", "Mostly Sunny", placeholderImage, "Few clouds"),
        ]

        static var sampleTodayWeather: [[String: String]] = [
            ["Feels Like": "70°F"],
            ["Pressure": "1013 hPa"],
            ["Humidity": "65%"],
            ["Wind": "5 mph NE"],
            ["Visibility": "10 miles"],
            ["Sunrise": "6:35 AM"],
            ["Sunset": "8:15 PM"],
        ]

        /// Create placeholder UIImages for preview
        static var placeholderImage: UIImage {
            // Return a system image as a UIImage
            if let image = UIImage(systemName: "sun.max.fill") {
                return image
            }
            return UIImage()
        }

        static var previews: some View {
            PortraitWeatherView(
                forecastArray: sampleForecasts,
                todayWeatherArray: sampleTodayWeather,
                theme: theme
            )
            .previewLayout(.fixed(width: 700, height: 500))
        }
    }
#endif
