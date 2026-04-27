//
//  ThreadSafeGlobals.swift
//  CATIE-TV
//
//  Created by GitHub Copilot on 24/06/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation

/// Thread-safe wrapper class for global variables that need concurrent access protection
enum ThreadSafeGlobals {
    // MARK: Internal

    static var tvStatus: Int {
        get {
            queue.sync { _tvStatus }
        }
        set {
            queue.async(flags: .barrier) {
                _tvStatus = newValue
            }
        }
    }

    static var communicationStatus: String? {
        get {
            queue.sync { _communicationStatus }
        }
        set {
            queue.async(flags: .barrier) {
                _communicationStatus = newValue
            }
        }
    }

    static var isNetworkReachable: Bool {
        get {
            queue.sync { _isNetworkReachable }
        }
        set {
            queue.async(flags: .barrier) {
                _isNetworkReachable = newValue
            }
        }
    }

    static var isSocketConnectionReachable: Bool {
        get {
            queue.sync { _isSocketConnectionReachable }
        }
        set {
            queue.async(flags: .barrier) {
                _isSocketConnectionReachable = newValue
            }
        }
    }

    static var isItFirstLaunch: Bool {
        get {
            queue.sync { _isItFirstLaunch }
        }
        set {
            queue.async(flags: .barrier) {
                _isItFirstLaunch = newValue
            }
        }
    }

    static var updateUIFromLocalData: Bool {
        get {
            queue.sync { _updateUIFromLocalData }
        }
        set {
            queue.async(flags: .barrier) {
                _updateUIFromLocalData = newValue
            }
        }
    }

    static var syncDataForAllModulesNotifyReceived: Bool {
        get {
            queue.sync { _syncDataForAllModulesNotifyReceived }
        }
        set {
            queue.async(flags: .barrier) {
                _syncDataForAllModulesNotifyReceived = newValue
            }
        }
    }

    static var callForDailyDataSync: Bool {
        get {
            queue.sync { _callForDailyDataSync }
        }
        set {
            queue.async(flags: .barrier) {
                _callForDailyDataSync = newValue
            }
        }
    }

    static var carousalsForDownload: Int {
        get {
            queue.sync { _carousalsForDownload }
        }
        set {
            queue.async(flags: .barrier) {
                _carousalsForDownload = newValue
            }
        }
    }

    static var downloadedCarousalCount: Int {
        get {
            queue.sync { _downloadedCarousalCount }
        }
        set {
            queue.async(flags: .barrier) {
                _downloadedCarousalCount = newValue

                // Handle didSet logic on main queue to avoid deadlock
                if _carousalsForDownload == newValue, _carousalsForDownload != 0, newValue != 0 {
                    DispatchQueue.main.async {
                        ThreadSafeGlobals.downloadedCarousalCount = 0
                        ThreadSafeGlobals.carousalsForDownload = 0
                        DDLogDebug("AppDelegate : Call carousal refresh")
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "refreshCarousalModel"), object: nil)
                    }
                }
            }
        }
    }

    static var siteLogoDownloaded: Bool {
        get {
            queue.sync { _siteLogoDownloaded }
        }
        set {
            queue.async(flags: .barrier) {
                _siteLogoDownloaded = newValue

                // Handle didSet logic on main queue to avoid deadlock
                if newValue == true {
                    DispatchQueue.main.async {
                        ThreadSafeGlobals.siteLogoDownloaded = false
                        DDLogDebug("AppDelegate : Call sitelogo refresh")
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "refreshSiteLogoModel"), object: nil)
                    }
                }
            }
        }
    }

    static var weatherIconsDownloaded: Int {
        get {
            queue.sync { _weatherIconsDownloaded }
        }
        set {
            queue.async(flags: .barrier) {
                _weatherIconsDownloaded = newValue

                // Handle didSet logic on main queue to avoid deadlock
                if newValue == 5 {
                    DispatchQueue.main.async {
                        ThreadSafeGlobals.weatherIconsDownloaded = 0
                        DDLogDebug("AppDelegate : Call weather refresh")
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "refreshWeatherModel"), object: nil)
                    }
                }
            }
        }
    }

    static var saraAlertWithAudio: Bool {
        get {
            queue.sync { _saraAlertWithAudio }
        }
        set {
            queue.async(flags: .barrier) {
                _saraAlertWithAudio = newValue

                // Handle didSet logic on main queue to avoid deadlock
                if newValue {
                    DispatchQueue.main.async {
                        ThreadSafeGlobals.saraAlertWithAudio = false
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "refreshSaraAlertModel"), object: nil)
                        DDLogDebug("AppDelegate : Call sara alert refresh")
                    }
                }
            }
        }
    }

    // MARK: Private

    // MARK: - Private Properties

    private static let queue = DispatchQueue(label: "com.statusSolutions.CATIE-TV.globals", attributes: .concurrent)

    // MARK: - TV Status

    private static var _tvStatus: Int = 1

    // MARK: - Communication Status

    private static var _communicationStatus: String?

    // MARK: - Network Status

    private static var _isNetworkReachable: Bool = false

    private static var _isSocketConnectionReachable: Bool = false

    // MARK: - Configuration Status

    private static var _isItFirstLaunch: Bool = true

    private static var _updateUIFromLocalData: Bool = true

    private static var _syncDataForAllModulesNotifyReceived: Bool = false

    private static var _callForDailyDataSync: Bool = false

    // MARK: - Download Counters

    private static var _carousalsForDownload: Int = 0

    private static var _downloadedCarousalCount: Int = 0

    private static var _siteLogoDownloaded: Bool = false

    private static var _weatherIconsDownloaded: Int = 0

    private static var _saraAlertWithAudio: Bool = false
}
