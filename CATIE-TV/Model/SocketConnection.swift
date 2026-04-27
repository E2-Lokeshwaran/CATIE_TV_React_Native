//
//  SocketConnection.swift
//  CATIE-TV
//
//  Created by Admin on 25/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation
import Starscream

// MARK: - webSocketConnection

class webSocketConnection: NSObject {
    // MARK: Lifecycle

    deinit {
        DDLogDebug("webSocketConnection: deinit - cleaning up resources")
        // Clean up all resources to prevent memory leaks
        closeSocketConnection()
        DDLogDebug("webSocketConnection: deinit - all resources cleaned up")
    }

    // MARK: Internal

    weak var mainViewdelegate: MainScreenDelegate?
    var reconnectionAttempts: Int = 0

    func startSocketConnection(withAddress: String, roomNumber: String) {
        SwiftTryCatch.try {
            DDLogDebug("SocketConnection : Starting connection - current state: isReconnecting=\(getReconnectingState()), attempts=\(reconnectionAttempts)")

            // Check if we should throttle reconnection attempts
            guard shouldAttemptReconnection() else {
                DDLogDebug("SocketConnection : Throttling reconnection attempt - too soon since last attempt")
                return
            }

            // Update timestamp for this connection attempt
            updateLastReconnectionTimestamp()

            // Clean up any existing connection state before starting new attempt
            cancelConnectionWatchdog()

            // Reset reconnection state when starting a new connection attempt
            updateReconnectingState(false)

            DispatchQueue.global().async {
                // Close any existing connection first
                socket.disconnect()
                DDLogDebug("SocketConnection : Closing existing socket before reconnecting")

                // Small delay to ensure cleanup
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    let urlString = "wss://\(withAddress)/webnotification/webnotifier/\(roomNumber.lowercased())/notification".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""

                    DDLogDebug("SocketConnection : Attempting to connect to \(urlString)")

                    // don't validate SSL certificates
                    let pinner = FoundationSecurity(allowSelfSigned: true)

                    // Create a new request with timeout
                    var request = URLRequest(url: URL(string: urlString)!)
                    request.timeoutInterval = 0

                    socket = WebSocket(request: request, certPinner: pinner)
                    socket.delegate = self
                    socket.connect()
                    DDLogDebug("SocketConnection : WebSocket is going to connect with URL \(String(describing: urlString))")

                    // Start watchdog to detect silent failures
                    self.startConnectionWatchdog() // Add a quick check for immediate connection failures (like SO_ERROR 61: Connection refused)
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                        DDLogDebug("SocketConnection : Quick failure check executing - isSocketConnectionReachable: \(isSocketConnectionReachable), isReconnecting: \(self.getReconnectingState())")

                        if !isSocketConnectionReachable, !self.getReconnectingState() {
                            DDLogDebug("SocketConnection : Quick failure check - connection failed within 3 seconds, likely immediate network error")

                            // Log this specific error type
                            self.logConnectionError("quick_failure_SO_ERROR")

                            // Cancel any existing watchdog since we're handling the failure
                            self.cancelConnectionWatchdog()

                            socket.disconnect()
                            self.scheduleReconnection(reason: "quick failure - immediate connection error (possibly SO_ERROR 61)")
                        } else {
                            DDLogDebug("SocketConnection : Quick failure check passed - isSocketConnectionReachable: \(isSocketConnectionReachable), isReconnecting: \(self.getReconnectingState())")
                        }
                    }
                }
            }

        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in startSocketConnection - \(String(describing: exception))")
            // If there's an exception during connection setup, schedule a retry
            scheduleReconnection(reason: "connection exception: \(String(describing: exception))")
        }
    }

    @objc func SendPingToServer() {
        SwiftTryCatch.try {
            guard let tvID = roomNo?.lowercased() else {
                DDLogDebug("SocketConnection : Cannot send ping - roomNo is nil")
                return
            }

            DDLogDebug("SocketConnection : send ping to get Reconnect-Websocket message and ping details - \(tvID):ping")
            socket.write(string: "\(tvID):ping")
        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in SendPingToServer - \(String(describing: exception))")
        }
    }

    @objc func sendDeviceDetailsToServer() {
        SwiftTryCatch.try {
            DDLogDebug("SocketConnection : send DeviceDetail to server called")

            guard let roomNumber = roomNo else {
                DDLogDebug("SocketConnection : Cannot send device details - roomNo is nil")
                return
            }

            var deviceProperties = [String: String]()

            let getDetails = DeviceDetails()
            deviceProperties["tvId"] = roomNumber
            deviceProperties["module"] = "deviceStatus"
            deviceProperties["ipAddr"] = getDetails.getIPAddress()
            deviceProperties["appVersion"] = getDetails.getAppVersion()
            deviceProperties["deviceOsVersion"] = getDetails.getOSVersion()
            deviceProperties["deviceType"] = getDetails.getDeviceType()
            deviceProperties["deviceDatetime"] = getDetails.getDateAndTime()
            deviceProperties["communicationStatus"] = communicationStatus
            deviceProperties["status"] = "connected"

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: deviceProperties, options: .prettyPrinted)

                guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
                    DDLogDebug("SocketConnection : Failed to convert JSON data to string")
                    return
                }

                let deviceStatus = "CATIE-SERVER:" + jsonString
                socket.write(string: deviceStatus)
                DDLogDebug("SocketConnection : Json object from dictionary - \(deviceStatus)")
            } catch {
                DDLogDebug("SocketConnection : Error while creating json object from dictionary in SocketConnection \(error.localizedDescription)")
            }
        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in sendDeviceDetailsToServer - \(String(describing: exception))")
        }
    }

    func closeSocketConnection() {
        SwiftTryCatch.try {
            DDLogDebug("SocketConnection : websocket connection closed")
            // Cancel any pending reconnection attempts
            cancelReconnection()
            socket.disconnect()
            isSocketConnectionReachable = false
            socket.delegate = nil
        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in closeSocketConnection - \(String(describing: exception))")
        }
    }

    func cancelReconnection() {
        DDLogDebug("SocketConnection : Canceling any pending reconnection attempts (was isReconnecting: \(getReconnectingState()))")

        // Ensure timer invalidation happens on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            if let timer = reconnectionTimer {
                DDLogDebug("SocketConnection : Invalidating existing reconnection timer: \(timer)")
                timer.invalidate()
            }
            reconnectionTimer = nil
        }

        cancelConnectionWatchdog()
        updateReconnectingState(false)
    }

    // MARK: Private

    private var reconnectionTimer: Timer?
    private var connectionWatchdog: Timer?
    private var isReconnecting = false

    // MARK: - State Management

    private let stateQueue = DispatchQueue(label: "com.catie.socketStateQueue")
    private var lastReconnectionTimestamp: Date?
    private var connectionErrors: [String: Int] = [:]

    // MARK: - State Management Methods

    private func updateReconnectingState(_ newState: Bool) {
        stateQueue.sync {
            isReconnecting = newState
        }
    }

    private func getReconnectingState() -> Bool {
        stateQueue.sync {
            isReconnecting
        }
    }

    private func shouldAttemptReconnection() -> Bool {
        stateQueue.sync {
            guard let timestamp = lastReconnectionTimestamp else {
                return true
            }

            return Date().timeIntervalSince(timestamp) > 5.0 // Min 5 seconds between attempts
        }
    }

    private func logConnectionError(_ error: String) {
        stateQueue.sync {
            connectionErrors[error, default: 0] += 1
            DDLogDebug("SocketConnection : Error stats - \(connectionErrors)")
        }
    }

    private func updateLastReconnectionTimestamp() {
        stateQueue.sync {
            lastReconnectionTimestamp = Date()
        }
    }

    /// Centralized method to schedule reconnection attempts
    private func scheduleReconnection(reason: String) {
        // Only schedule if we have a registered room
        guard tvStatus == 1 else {
            DDLogDebug("SocketConnection : Skipping reconnection scheduling for '\(reason)' - not registered (tvStatus = \(tvStatus))")
            return
        }

        // Log the connection error for tracking
        logConnectionError(reason)

        // If already reconnecting, cancel the existing attempt to start fresh
        if getReconnectingState() {
            DDLogDebug("SocketConnection : Canceling existing reconnection to start fresh for '\(reason)' (was on attempt #\(reconnectionAttempts))")
            cancelReconnection()
        } else {
            // Cancel any existing reconnection timer and watchdog even if not currently reconnecting
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                reconnectionTimer?.invalidate()
                reconnectionTimer = nil
            }
            cancelConnectionWatchdog()
        }

        // Use fixed 30-second interval for all reconnection attempts
        let backoffDelay = 30.0

        reconnectionAttempts += 1

        DDLogDebug("SocketConnection : Scheduling reconnection after '\(reason)' in \(backoffDelay) seconds (attempt #\(reconnectionAttempts))")
        DDLogDebug("SocketConnection : Connection stats: \(getConnectionStatistics())")

        // Set flag to indicate reconnection is in progress
        updateReconnectingState(true)

        // Schedule timer on main thread to ensure it's properly added to the run loop
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            // Double-check that we still want to reconnect
            guard getReconnectingState() else {
                DDLogDebug("SocketConnection : Reconnection was cancelled before timer could be scheduled")
                return
            }

            DDLogDebug("SocketConnection : Actually scheduling timer on main thread for '\(reason)' with \(backoffDelay)s delay")

            reconnectionTimer = Timer.scheduledTimer(withTimeInterval: backoffDelay, repeats: false) { [weak self] _ in
                SwiftTryCatch.try {
                    guard let self else {
                        DDLogDebug("SocketConnection : Self deallocated during reconnection timer")
                        return
                    }
                    guard self.getReconnectingState() else {
                        DDLogDebug("SocketConnection : Reconnection was cancelled before timer execution")
                        return
                    }
                    guard let address = domainAddress, let room = roomNo else {
                        DDLogDebug("SocketConnection : Cannot proceed with reconnection after '\(reason)' - missing connection data (address: \(domainAddress ?? "nil"), room: \(roomNo ?? "nil"))")
                        self.cancelReconnection()
                        return
                    }

                    DDLogDebug("SocketConnection : Executing scheduled reconnection after '\(reason)' (attempt #\(self.reconnectionAttempts))")

                    // Clear the timer reference since it's about to fire
                    self.reconnectionTimer = nil

                    self.startSocketConnection(withAddress: address, roomNumber: room)
                } catch: { exception in
                    DDLogDebug("SocketConnection : Exception in reconnection timer - \(String(describing: exception))")
                    // If timer execution fails, ensure we clean up the state
                    self?.cancelReconnection()
                }
            }

            DDLogDebug("SocketConnection : Timer successfully scheduled with reference: \(String(describing: reconnectionTimer))")
        }
    }

    /// Start a watchdog timer to detect silent connection failures
    private func startConnectionWatchdog() {
        // Cancel any existing watchdog
        connectionWatchdog?.invalidate()

        DDLogDebug("SocketConnection : Starting connection watchdog (20 second timeout)")

        // Schedule timer on main thread to ensure it's properly added to the run loop
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            // Set a 20-second watchdog to detect silent failures (increased from 15s to handle network-level errors like Connection refused)
            connectionWatchdog = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { [weak self] _ in
                SwiftTryCatch.try {
                    guard let self else {
                        return
                    }

                    // Check if we're still not connected after reasonable time and no delegate was called
                    if !isSocketConnectionReachable {
                        DDLogDebug("SocketConnection : Connection watchdog triggered - no response after 20 seconds, likely network-level failure (SO_ERROR, Connection refused, etc.), forcing reconnection")

                        // Log this specific error type
                        self.logConnectionError("watchdog_timeout")

                        // Cancel the watchdog
                        self.connectionWatchdog?.invalidate()
                        self.connectionWatchdog = nil

                        // Force disconnection and schedule reconnection
                        socket.disconnect()
                        self.scheduleReconnection(reason: "watchdog - network-level connection failure (possibly SO_ERROR 61: Connection refused)")
                    } else {
                        DDLogDebug("SocketConnection : Connection watchdog completed - connection is healthy")
                    }
                } catch: { exception in
                    DDLogDebug("SocketConnection : Exception in watchdog timer - \(String(describing: exception))")
                }
            }
        }
    }

    /// Cancel the connection watchdog timer
    private func cancelConnectionWatchdog() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            connectionWatchdog?.invalidate()
            connectionWatchdog = nil
        }
    }

    // MARK: - UI Type Data Fetching Logic

    /// Determines if data should be fetched using the common utility
    private func shouldFetchData(for dataType: DataFetchingUtility.DataType) -> Bool {
        DataFetchingUtility.shouldFetchData(
            for: dataType,
            mainVC: mainViewdelegate as? MainScreenViewController,
            context: "SocketConnection"
        )
    }
}

// MARK: WebSocketDelegate

extension webSocketConnection: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client _: WebSocketClient) {
        SwiftTryCatch.try {
            switch event {
            case .connected:
                DDLogDebug("SocketConnection : websocket connected successfully")
                reconnectionAttempts = 0 // Reset counter on successful connection
                resetConnectionStatistics() // Reset error tracking
                cancelReconnection() // Clear any pending reconnection attempts
                cancelConnectionWatchdog() // Cancel watchdog
                self.sendDeviceDetailsToServer()
                isSocketConnectionReachable = true
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "serverReachabilityChanged"), object: nil)

                getTVStatus()

                if pingServerTimer.isValid {
                    pingServerTimer.invalidate()
                }

                if pingTimer.isValid {
                    pingTimer.invalidate()
                }

                // Use block-based timers to avoid retain cycles
                pingServerTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                    self?.sendDeviceDetailsToServer()
                }
                pingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                    self?.SendPingToServer()
                }

            case let .disconnected(reason, code):
                DDLogDebug("SocketConnection : Websocket disconnected with reason \(reason) and code \(code)")

                cancelConnectionWatchdog() // Cancel watchdog
                isSocketConnectionReachable = false
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "serverReachabilityChanged"), object: nil)

                if pingServerTimer.isValid {
                    pingServerTimer.invalidate()
                }

                if pingTimer.isValid {
                    pingTimer.invalidate()
                }

                // Handle first launch scenario
                if tvStatus == 1 {
                    if isItFirstLaunch { // to display network down scenario in app first launch
                        DDLogDebug("SocketConnection : to display network down scenario in app first launch")
                        isItFirstLaunch = false
                        // Don't post notification again since it was already posted above
                    }

                    // Schedule reconnection using centralized method
                    scheduleReconnection(reason: "disconnected: \(reason) (code: \(code))")
                } else {
                    DDLogDebug("SocketConnection : No room is registered")
                }

            case let .text(text):
                DDLogDebug("SocketConnection : got message from websocket server - \(text)")

                if tvStatus == 1 {
                    DispatchQueue.global().async { [weak self] in
                        // update local storage values each time when changes are downloaded from server.
                        if text == "carousal" {
                            // Adding some delay to download the carousel slides, since downloading it immediately causing the half break image from server....
                            // Replace sleep with async delay that doesn't block the thread
                            DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) { [weak self] in
                                self?.mainViewdelegate?.getCarousalImages()
                            }
                        } else if text == "weather" {
                            // Weather is always fetched for all UI types (displayed in header)
                            self?.mainViewdelegate?.getWeather()
                        } else if text == "event" {
                            // Only fetch event data for UI types that display events
                            if self?.shouldFetchData(for: .events) == true {
                                self?.mainViewdelegate?.getEvents()
                            } else {
                                let uiType = (self?.mainViewdelegate as? MainScreenViewController)?.actualUIType ?? -1
                                DDLogDebug("SocketConnection : Skipping event fetch - UI type \(uiType) doesn't display events")
                            }
                        } else if text == "statusIndicator" {
                            // Only fetch status indicator data for UI types that display status indicators
                            if self?.shouldFetchData(for: .statusIndicators) == true {
                                self?.mainViewdelegate?.getStatusIndicator()
                            } else {
                                let uiType = (self?.mainViewdelegate as? MainScreenViewController)?.actualUIType ?? -1
                                DDLogDebug("SocketConnection : Skipping status indicator fetch - UI type \(uiType) doesn't display status indicators")
                            }
                        } else if text == "Radio" {
                            // Only fetch radio data for UI types that display radio
                            if self?.shouldFetchData(for: .radio) == true {
                                self?.mainViewdelegate?.getRadioFeed()
                            } else {
                                let uiType = (self?.mainViewdelegate as? MainScreenViewController)?.actualUIType ?? -1
                                let radioFlag = (self?.mainViewdelegate as? MainScreenViewController)?.tvRadioFlag ?? 1
                                DDLogDebug("SocketConnection : Skipping radio fetch - UI type \(uiType) with radioFlag \(radioFlag) doesn't display radio")
                            }
                        } else if text == "icon" { // Site logo
                            self?.mainViewdelegate?.getSiteLogo()
                        } else if text == "scrollmsg" {
                            self?.mainViewdelegate?.getScrollingMessageFeed()
                        } else if text == "saraAlert" {
                            self?.mainViewdelegate?.getSaraAlertFeed()
                        } else if text == "detach" {
                            tvStatus = 0

                            ApplicationState().resetUserDefaults()

                            // Cancel if any URLSessionDataTask running
                            self?.cancelAllURLSessionDataTask()

                            if pushLogFilesTimer.isValid {
                                pushLogFilesTimer.invalidate()
                            }
                            if pingServerTimer.isValid {
                                pingServerTimer.invalidate()
                            }
                            if pingTimer.isValid {
                                pingTimer.invalidate()
                            }

                            self?.mainViewdelegate?.updateRadioIcon(status: false, isNetworkDown: false)
                            self?.mainViewdelegate?.deleteLocalStorage()
                            socketConnection.closeSocketConnection()

                            self?.mainViewdelegate?.stopHomeViewUpdates()
                            viewUpdateHandlerConnection.mainViewdelegate = nil
                            viewUpdateHandlerConnection.managedObjectContext = nil

                            self?.mainViewdelegate?.presentRegistrationPage()
                            socketConnection.mainViewdelegate = nil

                        } else if text == "All" { // refreshing all the events
                            DDLogDebug("Socket connection : Refresh ack received.")
                            syncDataForAllModulesNotifyReceived = true
                            self?.syncDataForAllModules()
                        } else if text == "PushLogs" {
                            logHandlingConnection.pushLogsToServerusingJson()
                        } else if text == "showClock" {
                            self?.mainViewdelegate?.getClockFeed()
                        } else if text == "hideClock" {
                            self?.mainViewdelegate?.clockFailureResponse(message: "No need to show the clock")
                            self?.mainViewdelegate?.deleteRecords("Clock")
                        } else if text == "tvUIUpdate" {
                            self?.mainViewdelegate?.getCustomHomePage()
                        } else if text == "Reconnect Websocket" {
                            DDLogDebug("SocketConnection : Close existing connection and reconnect web socket")
                            guard let address = domainAddress, let room = roomNo else {
                                DDLogDebug("SocketConnection : Missing connection data for manual reconnect")
                                return
                            }

                            socketConnection.closeSocketConnection()
                            socketConnection.startSocketConnection(withAddress: address, roomNumber: room)
                        }
                    }
                } else {
                    DDLogDebug("SocketConnection : No room is registered")
                }

            case let .binary(data):
                DDLogDebug("SocketConnection : got data from websocket server \(data.count)")

            case let .error(error):
                // Enhanced error logging to capture network-level errors like SO_ERROR 61: Connection refused
                let errorDescription = String(describing: error)
                DDLogDebug("SocketConnection : websocket error: \(errorDescription)")

                // Log this error for tracking
                logConnectionError("websocket_error: \(errorDescription)")

                // Check for specific network-level errors that might not trigger other delegate methods
                if errorDescription.contains("SO_ERROR") ||
                    errorDescription.contains("Connection refused") ||
                    errorDescription.contains("Network is down") ||
                    errorDescription.contains("Host is down")
                {
                    DDLogDebug("SocketConnection : Detected network-level error - \(errorDescription)")
                    logConnectionError("network_level_error")
                }

                cancelConnectionWatchdog() // Cancel watchdog
                isSocketConnectionReachable = false
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "serverReachabilityChanged"), object: nil)

                // Schedule reconnection with detailed error info
                scheduleReconnection(reason: "network error: \(errorDescription)")

            case .ping:
                DDLogDebug("SocketConnection : websocket ping received")

            case .pong:
                DDLogDebug("SocketConnection : websocket pong received")

            case let .viabilityChanged(isViable):
                DDLogDebug("SocketConnection : websocket viability changed: \(isViable)")

            case let .reconnectSuggested(shouldReconnect):
                DDLogDebug("SocketConnection : websocket reconnect suggested: \(shouldReconnect)")

                // If the WebSocket library suggests reconnection, use a shorter backoff
                if shouldReconnect {
                    scheduleReconnection(reason: "suggested reconnection")
                }

            case .cancelled:
                DDLogDebug("SocketConnection : websocket cancelled")
                cancelConnectionWatchdog() // Cancel watchdog

            case .peerClosed:
                DDLogDebug("SocketConnection : websocket peer closed")

                cancelConnectionWatchdog() // Cancel watchdog
                isSocketConnectionReachable = false
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "serverReachabilityChanged"), object: nil)

                // Schedule reconnection for peer closed event
                scheduleReconnection(reason: "peer closed")
            }
        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in didReceive - \(String(describing: exception))")
        }
    }

    func cancelAllURLSessionDataTask() {
        SwiftTryCatch.try {
            DDLogDebug("SocketConnection : cancel if any URLSessionDataTask running")

            if weatherConnection.weatherDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running weatherDataTask")
                weatherConnection.weatherDataTask?.cancel()
            }
            if eventsConnection.eventDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running eventDataTask")
                eventsConnection.eventDataTask?.cancel()
            }
            if statusIndicatorConnection.statusDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running statusDataTask")
                statusIndicatorConnection.statusDataTask?.cancel()
            }
            if carousalImagesConnection.carousalDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running carousalDataTask")
                carousalImagesConnection.carousalDataTask?.cancel()
            }
            if radioResponseConnection.radioDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running radioDataTask")
                radioResponseConnection.radioDataTask?.cancel()
            }
            if siteLogoImageConnection.siteLogoDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running siteLogoDataTask")
                siteLogoImageConnection.siteLogoDataTask?.cancel()
            }
            if scrollingMsgConnection.scrollMessageDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running scrollMessageDataTask")
                scrollingMsgConnection.scrollMessageDataTask?.cancel()
            }
            if saraAlertConnection.saraAlertDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running saraAlertDataTask")
                saraAlertConnection.saraAlertDataTask?.cancel()
            }
            if clockConnection.clockDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running clockDataTask")
                clockConnection.clockDataTask?.cancel()
            }
            if customHomePageConnection.CustomHomePageDataTask?.state == .running {
                DDLogDebug("SocketConnection : cancel running CustomHomePageDataTask")
                customHomePageConnection.CustomHomePageDataTask?.cancel()
            }

        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in cancelAllURLSessionDataTask - \(String(describing: exception))")
        }
    }

    func getTVStatus() {
        SwiftTryCatch.try {
            DispatchQueue.global().async {
                // During web socket connect need to get display type & tvStatus first, so calling getCustomHomePage in separate thread.
                self.mainViewdelegate?.getCustomHomePage()
            }
        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in getTVStatus - \(String(describing: exception))")
        }
    }

    func syncDataForAllModules() {
        SwiftTryCatch.try {
            DDLogDebug("Socket connection : sync data for all modules")

            DispatchQueue.global().async {
                // Always fetch these modules (required for all UI types)
                self.mainViewdelegate?.getSiteLogo()
                self.mainViewdelegate?.getWeather() // Weather is always fetched for all UI types
                self.mainViewdelegate?.getCarousalImages()
                self.mainViewdelegate?.getScrollingMessageFeed()
                self.mainViewdelegate?.getSaraAlertFeed()
                self.mainViewdelegate?.getClockFeed()

                // Conditionally fetch based on UI type and configuration

                if self.shouldFetchData(for: .events) {
                    DDLogDebug("SocketConnection: Fetching events data for syncAllDataModules")
                    self.mainViewdelegate?.getEvents()
                } else {
                    DDLogDebug("SocketConnection: Skipping events data for UI type")
                }

                if self.shouldFetchData(for: .statusIndicators) {
                    DDLogDebug("SocketConnection: Fetching status indicators data for syncAllDataModules")
                    self.mainViewdelegate?.getStatusIndicator()
                } else {
                    DDLogDebug("SocketConnection: Skipping status indicators data for UI type")
                }

                if self.shouldFetchData(for: .radio) {
                    DDLogDebug("SocketConnection: Fetching radio data for syncAllDataModules")
                    self.mainViewdelegate?.getRadioFeed()
                } else {
                    DDLogDebug("SocketConnection: Skipping radio data for UI type")
                }
            }

        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in syncDataForAllModules - \(String(describing: exception))")
        }
    }

    func checkAndSyncDataForModule() {
        SwiftTryCatch.try {
            DDLogDebug("Socket connection : Check and sync data for required modules")

            DispatchQueue.global().async {
                // Create an instance of SafeDict
                let safeDict = StatusCodeDict.shared

                // Always sync essential modules regardless of UI type
                if safeDict.getValue(key: "statusCodeForSiteLogo") != 200 {
                    DDLogDebug("Socket connection : sync data for siteLogo module")
                    self.mainViewdelegate?.getSiteLogo()
                }

                // Always sync weather data (always needed for all UI types)
                if safeDict.getValue(key: "statusCodeForWeather") != 200 {
                    DDLogDebug("Socket connection : sync data for weather module")
                    self.mainViewdelegate?.getWeather()
                }

                // Conditionally sync status indicator data
                if safeDict.getValue(key: "statusCodeForStatusIndicator") != 200 {
                    if self.shouldFetchData(for: .statusIndicators) {
                        DDLogDebug("Socket connection : sync data for statusIndicator module")
                        self.mainViewdelegate?.getStatusIndicator()
                    } else {
                        DDLogDebug("Socket connection : skipping statusIndicator sync - not displayed in current UI type")
                    }
                }

                // Conditionally sync event data
                if safeDict.getValue(key: "statusCodeForEvent") != 200 {
                    if self.shouldFetchData(for: .events) {
                        DDLogDebug("Socket connection : sync data for event module")
                        self.mainViewdelegate?.getEvents()
                    } else {
                        DDLogDebug("Socket connection : skipping event sync - not displayed in current UI type")
                    }
                }

                // Always sync carousel (needed for all UI types)
                if safeDict.getValue(key: "statusCodeForCarousal") != 200 {
                    DDLogDebug("Socket connection : sync data for carousal module")
                    self.mainViewdelegate?.getCarousalImages()
                }

                // Conditionally sync radio data
                if safeDict.getValue(key: "statusCodeForRadio") != 200 {
                    if self.shouldFetchData(for: .radio) {
                        DDLogDebug("Socket connection : sync data for radio module")
                        self.mainViewdelegate?.getRadioFeed()
                    } else {
                        DDLogDebug("Socket connection : skipping radio sync - not displayed in current UI type")
                    }
                }

                // Always sync scrolling messages (may be needed for all UI types)
                if safeDict.getValue(key: "statusCodeForScrollMessage") != 200 {
                    DDLogDebug("Socket connection : sync data for scrollMessage module")
                    self.mainViewdelegate?.getScrollingMessageFeed()
                }

                // Always sync SARA alerts (may be needed for all UI types)
                if safeDict.getValue(key: "statusCodeForSaraAlert") != 200 {
                    DDLogDebug("Socket connection : sync data for saraAlert module")
                    self.mainViewdelegate?.getSaraAlertFeed()
                }

                // Always sync clock (may be needed for all UI types)
                if safeDict.getValue(key: "statusCodeForClock") != 200 {
                    DDLogDebug("Socket connection : sync data for clock module")
                    self.mainViewdelegate?.getClockFeed()
                }
            }

        } catch: { exception in
            DDLogDebug("SocketConnection : Exception in checkAndSyncDataForModule - \(String(describing: exception))")
        }
    }
}

// MARK: - Debugging Methods

extension webSocketConnection {
    func getConnectionStatistics() -> [String: Any] {
        stateQueue.sync {
            [
                "reconnectionAttempts": reconnectionAttempts,
                "isReconnecting": isReconnecting,
                "lastReconnectionTimestamp": lastReconnectionTimestamp?.timeIntervalSince1970 ?? 0,
                "connectionErrors": connectionErrors,
                "isSocketConnectionReachable": isSocketConnectionReachable,
            ]
        }
    }

    func resetConnectionStatistics() {
        stateQueue.sync {
            connectionErrors.removeAll()
            reconnectionAttempts = 0
            lastReconnectionTimestamp = nil
        }
        DDLogDebug("SocketConnection : Connection statistics reset")
    }
}
