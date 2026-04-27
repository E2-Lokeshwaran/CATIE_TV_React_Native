//
//  DataFetchingUtility.swift
//  CATIE-TV
//
//  Created by Rovo Dev on 25/01/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

// MARK: - DataFetchingUtility

/// Utility class for determining whether data should be fetched based on UI type and configuration
class DataFetchingUtility {
    /// Data types that can be conditionally fetched
    enum DataType {
        case weather
        case events
        case statusIndicators
        case radio
    }

    /// Determines if data should be fetched based on current UI type and configuration
    /// - Parameters:
    ///   - dataType: The type of data to check
    ///   - uiType: The current UI type from server (actualUIType)
    ///   - radioFlag: The radio flag (1 = show, 0 = hide) - only used for radio data type
    ///   - context: Context string for logging (e.g., "SocketConnection", "ViewUpdateHandler")
    /// - Returns: True if data should be fetched, false otherwise
    static func shouldFetchData(
        for dataType: DataType,
        uiType: Int,
        radioFlag: Int = 1,
        context: String = "DataFetchingUtility"
    ) -> Bool {
        switch dataType {
        case .weather:
            // Weather data should be fetched for all UI types as it's always displayed
            return true

        case .events:
            // Events should only be fetched for UI types 1 and 3
            switch uiType {
            case 1,
                 3:
                // UI Types 1, 3: Full content layouts with events - fetch data
                return true
            case 2,
                 4,
                 5,
                 6:
                // UI Types 2, 4, 5, 6: No events displayed - skip data
                return false
            default:
                // Unknown UI type - fetch by default for safety
                DDLogDebug("\(context): Unknown UI type \(uiType), fetching \(dataType) by default")
                return true
            }

        case .statusIndicators:
            // Status indicators should be fetched for UI types 1, 2, and 3
            switch uiType {
            case 1,
                 2,
                 3:
                // UI Types 1, 2, 3: Layouts with status indicators - fetch data
                return true
            case 4,
                 5,
                 6:
                // UI Types 4, 5, 6: No status indicators displayed - skip data
                return false
            default:
                // Unknown UI type - fetch by default for safety
                DDLogDebug("\(context): Unknown UI type \(uiType), fetching \(dataType) by default")
                return true
            }

        case .radio:
            // Radio follows UI type + radio flag rules
            switch uiType {
            case 1,
                 2,
                 3,
                 4:
                // UI Types 1-4: Full content layouts - always fetch radio
                return true
            case 5,
                 6:
                // UI Types 5-6: Fetch radio only if tvRadioFlag == 1
                return radioFlag == 1
            default:
                // Unknown UI type - fetch by default for safety
                DDLogDebug("\(context): Unknown UI type \(uiType), fetching \(dataType) by default")
                return true
            }
        }
    }

    /// Convenience method for MainScreenViewController-based checks
    /// - Parameters:
    ///   - dataType: The type of data to check
    ///   - mainVC: The MainScreenViewController instance
    ///   - context: Context string for logging
    /// - Returns: True if data should be fetched, false otherwise
    static func shouldFetchData(
        for dataType: DataType,
        mainVC: MainScreenViewController?,
        context: String = "DataFetchingUtility"
    ) -> Bool {
        guard let mainVC else {
            // If we can't access the main view controller, fetch by default for safety
            DDLogDebug("\(context): Cannot access MainScreenViewController, fetching \(dataType) by default")
            return true
        }

        return shouldFetchData(
            for: dataType,
            uiType: mainVC.actualUIType,
            radioFlag: mainVC.tvRadioFlag,
            context: context
        )
    }
}
