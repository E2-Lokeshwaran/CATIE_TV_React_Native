//
//  AppDelegate.swift
//  CATIE-TV
//
//  Created by Admin on 24/04/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import CocoaLumberjackSwift // Customized log writing framework
import CoreData // Default core data framework
import Network

// import Sentry
import Starscream // WebSocket client
import UIKit // User interface framework

// MARK: - Global variables

var domainAddress: String? // Server ip/domain address
var roomNo: String?
var userID: String?

/// Thread-safe global variables using ThreadSafeGlobals wrapper
var communicationStatus: String? {
    get { ThreadSafeGlobals.communicationStatus }
    set { ThreadSafeGlobals.communicationStatus = newValue }
}

var isNetworkReachable: Bool {
    get { ThreadSafeGlobals.isNetworkReachable }
    set { ThreadSafeGlobals.isNetworkReachable = newValue }
}

var isSocketConnectionReachable: Bool {
    get { ThreadSafeGlobals.isSocketConnectionReachable }
    set { ThreadSafeGlobals.isSocketConnectionReachable = newValue }
}

var isItFirstLaunch: Bool {
    get { ThreadSafeGlobals.isItFirstLaunch }
    set { ThreadSafeGlobals.isItFirstLaunch = newValue }
}

var tvStatus: Int {
    get { ThreadSafeGlobals.tvStatus }
    set { ThreadSafeGlobals.tvStatus = newValue }
}

var updateUIFromLocalData: Bool {
    get { ThreadSafeGlobals.updateUIFromLocalData }
    set { ThreadSafeGlobals.updateUIFromLocalData = newValue }
}

var syncDataForAllModulesNotifyReceived: Bool {
    get { ThreadSafeGlobals.syncDataForAllModulesNotifyReceived }
    set { ThreadSafeGlobals.syncDataForAllModulesNotifyReceived = newValue }
}

var callForDailyDataSync: Bool {
    get { ThreadSafeGlobals.callForDailyDataSync }
    set { ThreadSafeGlobals.callForDailyDataSync = newValue }
}

var carousalsForDownload: Int {
    get { ThreadSafeGlobals.carousalsForDownload }
    set { ThreadSafeGlobals.carousalsForDownload = newValue }
}

var downloadedCarousalCount: Int {
    get { ThreadSafeGlobals.downloadedCarousalCount }
    set { ThreadSafeGlobals.downloadedCarousalCount = newValue }
}

var siteLogoDownloaded: Bool {
    get { ThreadSafeGlobals.siteLogoDownloaded }
    set { ThreadSafeGlobals.siteLogoDownloaded = newValue }
}

var weatherIconsDownloaded: Int {
    get { ThreadSafeGlobals.weatherIconsDownloaded }
    set { ThreadSafeGlobals.weatherIconsDownloaded = newValue }
}

var saraAlertWithAudio: Bool {
    get { ThreadSafeGlobals.saraAlertWithAudio }
    set { ThreadSafeGlobals.saraAlertWithAudio = newValue }
}

// var defaultDSN = "https://aea7efdc29fb428a90d27c8f6dcfd874@appmonitor.e2infosystems.in/17"

// MARK: - WebSocket global connections

var socket = WebSocket(request: URLRequest(url: URL(string: "wss:")!))
var socketConnection = webSocketConnection()
var weatherConnection = WeatherModel()
var eventsConnection = EventsModel()
var statusIndicatorConnection = statusIndicatorModel()
var carousalImagesConnection = CarousalModel()
var radioResponseConnection = RadioModel()
var logHandlingConnection = LogHandlingModel()
var siteLogoImageConnection = SiteLogoModel()
var scrollingMsgConnection = ScrollMessageModel()
var saraAlertConnection = SaraAlertModel()

var clockConnection = ClockModel()
var customHomePageConnection = CustomHomePageModel()

var viewUpdateHandlerConnection = ViewUpdateHandler()

var pingServerTimer = Timer() // Used to ping server for every (x) second interval
var pingTimer = Timer() // Used to get Reconnect Websocket message

// MARK: - Customized log writing

var logFileManager: DDLogFileManagerDefault!
var fileLogger: DDFileLogger!

var pushLogFilesTimer = Timer() // Used to push app log files to server for every (x) second interval

// MARK: - MainScreenDelegate

protocol MainScreenDelegate: AnyObject {
    func presentRegistrationPage()

    func stopHomeViewUpdates()

    func deleteLocalStorage()
    func deleteRecords(_ entityName: String?)

    func getWeather()
    func weatherSuccessResponse()
    func weatherFailureResponse(message: String, isNetworkError: Bool)

    func getEvents()
    func eventsSuccessResponse()
    func eventFailureResponse(message: String, isNetworkError: Bool)

    func getStatusIndicator()
    func statusIndicatorSuccessResponse()
    func statusIndicatorFailureResponse(message: String, isNetworkError: Bool)

    func getCarousalImages()
    func carousalImagesSuccessResponse()
    func CarousalImagesFailureResponse(message: String, isNetworkError: Bool)

    func getSiteLogo()
    func siteLogoSuccessResponse()
    func siteLogoFailureResponse(message: String, isNetworkError: Bool)

    func getRadioFeed()
    func radioFeedSuccessResponse()
    func radioFeedFailureResponse(message: String, isNetworkError: Bool)
    func updateRadioIcon(status: Bool, isNetworkDown: Bool)

    func getScrollingMessageFeed()
    func scrollingMsgSuccessResponse()
    func scrollingMsgFailureResponse(message: String, isNetworkError: Bool)

    func getSaraAlertFeed()
    func saraAlertSuccessResponse(_ saraAlertData: [SaraAlert], _ saraAlertHeader: [SaraHeader], _ saraAlertFooter: [SaraFooter], _ saraAlertBody: [SaraBody], _ saraAlertBodyText: [SaraBodyText], _ saraAlertBodyIndividual: [SaraBodyIndividual])
    func saraAlertFailureResponse(message: String, isNetworkError: Bool)

    func getClockFeed()
    func clockSuccessResponse()
    func clockFailureResponse(message: String, isNetworkError: Bool)

    func getCustomHomePage()
    func customHomePageSuccessResponse(_ customHomePage: [CustomHomePage]?)
    func customHomePageFailureResponse(message: String, isNetworkError: Bool)
}

extension MainScreenDelegate {
    /// Default implementations with optional parameters
    func weatherFailureResponse(message: String) {
        weatherFailureResponse(message: message, isNetworkError: false)
    }

    func eventFailureResponse(message: String) {
        eventFailureResponse(message: message, isNetworkError: false)
    }

    func statusIndicatorFailureResponse(message: String) {
        statusIndicatorFailureResponse(message: message, isNetworkError: false)
    }

    func CarousalImagesFailureResponse(message: String) {
        CarousalImagesFailureResponse(message: message, isNetworkError: false)
    }

    func siteLogoFailureResponse(message: String) {
        siteLogoFailureResponse(message: message, isNetworkError: false)
    }

    func radioFeedFailureResponse(message: String) {
        radioFeedFailureResponse(message: message, isNetworkError: false)
    }

    func scrollingMsgFailureResponse(message: String) {
        scrollingMsgFailureResponse(message: message, isNetworkError: false)
    }

    func saraAlertFailureResponse(message: String) {
        saraAlertFailureResponse(message: message, isNetworkError: false)
    }

    func clockFailureResponse(message: String) {
        clockFailureResponse(message: message, isNetworkError: false)
    }

    func customHomePageFailureResponse(message: String) {
        customHomePageFailureResponse(message: message, isNetworkError: false)
    }
}

// MARK: - AppDelegate

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UIWindowSceneDelegate {
    // MARK: Internal

    var window: UIWindow?

    // check for internet connectivity using NWPathMonitor

    let monitor = NWPathMonitor()

    var isReachableOnCellular: Bool = true

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        // The persistent container for the application. This implementation
        // creates and returns a container, having loaded the store for the
        // application to it. This property is optional since there are legitimate
        // error conditions that could cause the creation of the store to fail.
        let container = NSPersistentContainer(name: "CATIE_TV")
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                // Typical reasons for an error here include:
                // * The parent directory does not exist, cannot be created, or disallows writing.
                // * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                // * The device is out of space.
                // * The store could not be migrated to the current model version.
                // Check the error message to determine what the actual problem was.
                DDLogDebug("AppDelegate : Unresolved error \(error), \(error.userInfo)")
            }
        })

        // Automatic migration for coreData
        // This will handle whenever new field is added to coreData
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSMigratePersistentStoresAutomaticallyOption
        )
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSInferMappingModelAutomaticallyOption
        )
        return container
    }()

    // MARK: - Scene Delegate Methods

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        DDLogDebug("AppDelegate: Scene will connect")

        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }

        window = UIWindow(windowScene: windowScene)

        // Initialize the main controller from storyboard using the correct storyboard path
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let mainViewController = storyboard.instantiateInitialViewController() {
            window?.rootViewController = mainViewController
            window?.makeKeyAndVisible()
            DDLogDebug("AppDelegate: Successfully loaded main view controller")
        } else {
            DDLogDebug("AppDelegate: Failed to load view controller from Main.storyboard")
            // Fallback to loading with explicit path
            let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle(for: type(of: self)))
            if let controller = mainStoryboard.instantiateInitialViewController() {
                window?.rootViewController = controller
                window?.makeKeyAndVisible()
                DDLogDebug("AppDelegate: Successfully loaded main view controller with fallback method")
            } else {
                DDLogDebug("AppDelegate: All attempts to load main view controller failed")
            }
        }
    }

    func sceneDidDisconnect(_: UIScene) {
        DDLogDebug("AppDelegate: Scene did disconnect")
    }

    func sceneDidBecomeActive(_: UIScene) {
        DDLogDebug("AppDelegate: Scene did become active")

        communicationStatus = "1"
        if isSocketConnectionReachable {
            socketConnection.sendDeviceDetailsToServer()
        }
    }

    func sceneWillResignActive(_: UIScene) {
        DDLogDebug("AppDelegate: Scene will resign active")
    }

    func sceneWillEnterForeground(_: UIScene) {
        DDLogDebug("AppDelegate: Scene will enter foreground")

        communicationStatus = "1"
        if isSocketConnectionReachable {
            socketConnection.sendDeviceDetailsToServer()
        }
    }

    func sceneDidEnterBackground(_: UIScene) {
        DDLogDebug("AppDelegate: Scene did enter background")

        communicationStatus = "5"
        if isSocketConnectionReachable {
            socketConnection.sendDeviceDetailsToServer()
        }
    }

    // MARK: - UIScene Lifecycle Support

    func application(_: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        DDLogDebug("AppDelegate: Creating scene configuration")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_: UIApplication, didDiscardSceneSessions _: Set<UISceneSession>) {
        DDLogDebug("AppDelegate: Did discard scene sessions")
    }

    // MARK: - Application life cycle

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        SwiftTryCatch.try {
            // Override point for customization after application launch.

            // Make sure to comment this line before uploading to app store
//            SentrySDK.start { options in
//                options.dsn = defaultDSN
//                options.debug = false // Enabled debug when first installing is always helpful
//
//                // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
//                // We recommend adjusting this value in production.
//                options.tracesSampleRate = 1.0
//            }

            self.initializeLogFileManager()

            communicationStatus = "1"

            startMonitoring()

            let queue = DispatchQueue(label: "NetworkMonitor")
            monitor.start(queue: queue)

            DDLogDebug("AppDelegate: Application finished launching - using UIScene lifecycle")

        } catch: { exception in
            DDLogDebug("AppDelegate : Exception in didFinishLaunchingWithOptions - \(String(describing: exception))")
        }

        return true
    }

    func startMonitoring() {
        SwiftTryCatch.try {
            monitor.pathUpdateHandler = { [weak self] path in
                self?.status = path.status
                self?.isReachableOnCellular = path.isExpensive

                if path.status == .unsatisfied {
                    isNetworkReachable = false
                    DDLogDebug("AppDelegate : network is not reachable")
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "networkReachabilityChanged"), object: nil)
                    // post connected notification
                } else if path.status == .satisfied {
                    isNetworkReachable = true
                    DDLogDebug("AppDelegate : network is reachable****")
                    if isSocketConnectionReachable {
                        socketConnection.sendDeviceDetailsToServer()
                    }
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "networkReachabilityChanged"), object: nil)
                    // post disconnected notification
                } else if path.status == .requiresConnection {
                    DDLogDebug("AppDelegate : The path does not currently have a usable route, but a connection attempt will trigger network attachment.")
                }
                //            print(path.isExpensive)
            }

        } catch: { exception in
            DDLogDebug("AppDelegate : Exception in startMonitoring - \(String(describing: exception))")
        }
    }

    func stopMonitoring() {
        SwiftTryCatch.try {
            monitor.cancel()
        } catch: { exception in
            DDLogDebug("AppDelegate : Exception in stopMonitoring - \(String(describing: exception))")
        }
    }

    // Legacy lifecycle methods removed - using UIScene lifecycle instead
    // These events are now handled in SceneDelegate

    func applicationDidReceiveMemoryWarning(_: UIApplication) {
        SwiftTryCatch.try {
            DDLogDebug("AppDelegate : Memory warning has been received from application")
        } catch: { exception in
            DDLogDebug("AppDelegate : Exception in applicationDidReceiveMemoryWarning - \(String(describing: exception))")
        }
    }

    func applicationWillTerminate(_: UIApplication) {
        SwiftTryCatch.try {
            DDLogDebug("AppDelegate : application will terminate called")
            communicationStatus = "2"
            self.saveContext()
            if isSocketConnectionReachable {
                socketConnection.sendDeviceDetailsToServer()
            }
            socketConnection.closeSocketConnection()
            stopMonitoring()
        } catch: { exception in
            DDLogDebug("AppDelegate : Exception in applicationWillTerminate - \(String(describing: exception))")
        }
    }

    // MARK: - Customized log handling

    func initializeLogFileManager() {
        SwiftTryCatch.try {
            if logFileManager == nil {
                let docDirectory: NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0] as NSString
                let logPath = docDirectory.appendingPathComponent("/DebugLogs")

                DDLogDebug("AppDelegate : debugging log file location \(logPath)")
                if !FileManager.default.fileExists(atPath: logPath) {
                    do {
                        try FileManager.default.createDirectory(atPath: logPath, withIntermediateDirectories: false, attributes: nil)
                    } catch {
                        print("Error creating log directory: \(error)")
                    }
                }

                logFileManager = DDLogFileManagerDefault(logsDirectory: logPath)
                fileLogger = DDFileLogger(logFileManager: logFileManager)

                let dateFormatter = DateFormatter()
                dateFormatter.formatterBehavior = .behavior10_4 // 10.4+ style
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss:SSS"

                fileLogger.rollingFrequency = 2 * 24 * 60 * 60 // 2 day
                fileLogger.maximumFileSize = 2 * 1024 * 1024 // 2MB
                fileLogger.logFileManager.maximumNumberOfLogFiles = 2 // maximum of 2 files
                fileLogger.logFormatter = DDLogFileFormatterDefault(dateFormatter: dateFormatter)
                dynamicLogLevel = DDLogLevel.debug

                if #available(tvOS 17.0, *) {
                    // Modern OS logging for tvOS 16+
                    DDLog.add(DDOSLogger.sharedInstance)
                    DDLogDebug("AppDelegate: Using DDOSLogger for tvOS 16+")
                } else {
                    // Legacy console logging for tvOS 15 and below
                    if let ttyLogger = DDTTYLogger.sharedInstance {
                        DDLog.add(ttyLogger)
                        DDLogDebug("AppDelegate: Using DDTTYLogger for older tvOS versions")
                    } else {
                        print("Warning: Failed to initialize DDTTYLogger")
                    }
                }

                DDLog.add(fileLogger)
                DDLogDebug("AppDelegate : debugging log file location \(logPath)")
                DDLogDebug("AppDelegate : Log file manager has been initialized successfully")

            } else {
                DDLogDebug("AppDelegate : Log file manager initialization failed")
            }
        } catch: { exception in
            DDLogDebug("AppDelegate : Exception in initializeLogFileManager - \(String(describing: exception))")
        }
    }

    // MARK: - Core Data Saving support

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                DDLogDebug("AppDelegate : Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: Private

    private var status: NWPath.Status = .requiresConnection
}
