//
//  ScrollDurationCalculator.swift
//  CATIE-TV
//
//  Created by Claude on 25/01/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

/// Centralized scroll duration calculation for consistent timing across all content types
enum ScrollDurationCalculator {
    // MARK: Internal

    // MARK: - Events Duration Calculation

    /// Calculates optimal scroll duration for events based on content size
    /// - Parameter eventCount: Number of events to display
    /// - Returns: Calculated duration in seconds
    static func calculateEventsDuration(for eventCount: Int) -> Double {
        guard eventCount > 0 else {
            DDLogDebug("ScrollDurationCalculator: No events, using minimum duration")
            return minimumEventsDuration
        }

        // Calculate number of rows (2 events per row in portrait mode)
        let numberOfRows = max(1, (eventCount + 1) / 2)

        // Calculate base duration: reading time per row * number of rows
        let calculatedDuration = Double(numberOfRows) * baseSecondsPerEventRow

        // Apply minimum constraint only (no maximum limit)
        let finalDuration = max(minimumEventsDuration, calculatedDuration)

        DDLogDebug("ScrollDurationCalculator: Events - Count: \(eventCount), Rows: \(numberOfRows), Duration: \(finalDuration)s")

        return finalDuration
    }

    // MARK: - Weather Duration Calculation

    /// Calculates optimal scroll duration for weather based on content size
    /// - Parameters:
    ///   - forecastCount: Number of forecast items
    ///   - todayWeatherCount: Number of today's weather detail items
    /// - Returns: Calculated duration in seconds
    static func calculateWeatherDuration(forecastCount: Int, todayWeatherCount: Int) -> Double {
        let totalItems = forecastCount + todayWeatherCount

        guard totalItems > 0 else {
            DDLogDebug("ScrollDurationCalculator: No weather items, using minimum duration")
            return minimumWeatherDuration
        }

        // Calculate base duration: reading time per item * number of items
        let calculatedDuration = Double(totalItems) * baseSecondsPerWeatherItem

        // Apply minimum constraint only (no maximum limit)
        let finalDuration = max(minimumWeatherDuration, calculatedDuration)

        DDLogDebug("ScrollDurationCalculator: Weather - Forecast: \(forecastCount), Today: \(todayWeatherCount), Total: \(totalItems), Duration: \(finalDuration)s")

        return finalDuration
    }

    // MARK: Private

    // MARK: - Constants for Events

    /// Base reading time per event row (2 events per row in portrait mode)
    private static let baseSecondsPerEventRow: Double = 4.0

    /// Minimum duration for events to ensure readability
    private static let minimumEventsDuration: Double = 10.0

    // MARK: - Constants for Weather

    /// Base reading time per weather item
    private static let baseSecondsPerWeatherItem: Double = 3.0

    /// Minimum duration for weather to ensure readability
    private static let minimumWeatherDuration: Double = 8.0
}
