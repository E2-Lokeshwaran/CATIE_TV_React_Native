//
//  MainScreenViewController.swift
//  CATIE-TV
//
//  Created by Pavithran on 13/12/19.
//  Copyright © 2019 statusSolutions. All rights reserved.
//

import AVKit
import CocoaLumberjackSwift
import Combine
import CoreData
import CoreImage
import SwiftUI
import UIKit

// MARK: - MainScreenViewController

class MainScreenViewController: UIViewController, MainScreenDelegate,
    NarrationAudioPlayerDelegate
{
    // MARK: Lifecycle

    deinit {
        DDLogDebug("MainScreenViewController: deinit - cleaning up resources")

        // Invalidate ALL timers to prevent memory leaks
        updateDateTimer?.invalidate()
        updateDateTimer = nil
        scrollbarTimer?.invalidate()
        scrollbarTimer = nil
        carousalImageTimer?.invalidate()
        carousalImageTimer = nil
        saraAlertFlashTimer?.invalidate()
        saraAlertFlashTimer = nil
        weatherDisplayTimer?.invalidate()
        weatherDisplayTimer = nil
        eventAnimationTimer?.invalidate()
        eventAnimationTimer = nil
        onGoingEventScheduleTimer?.invalidate()
        onGoingEventScheduleTimer = nil
        statusAnimationTimer?.invalidate()
        statusAnimationTimer = nil
        setClockTimer?.invalidate()
        setClockTimer = nil
        displayTimer?.invalidate()
        displayTimer = nil

        // Cancel portrait event update work item if it exists
        portraitEventUpdateWorkItem?.cancel()
        portraitEventUpdateWorkItem = nil

        // Remove ALL NotificationCenter observers
        NotificationCenter.default.removeObserver(self, name: .narrationDidStart, object: nil)
        NotificationCenter.default.removeObserver(self, name: .narrationDidFailToLoad, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "networkReachabilityChanged"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "serverReachabilityChanged"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "refreshCarousalModel"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "refreshSiteLogoModel"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "refreshWeatherModel"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "refreshSaraAlertModel"), object: nil)

        // Clear delegates to prevent callbacks to deallocated object
        radioConnection.mainViewdelegate = nil
        // Only nil the shared narration player's delegate if it still points to this instance,
        // to avoid clearing a delegate that was already reassigned to a new MainScreenViewController
        if narrationAudioPlayer.delegate === self {
            narrationAudioPlayer.delegate = nil
        }
        saraAlertAudioPlayer?.stop()
        saraAlertAudioPlayer = nil

        // Clear portrait view controller reference
        if let portraitVC = portraitViewController {
            portraitVC.willMove(toParent: nil)
            portraitVC.view.removeFromSuperview()
            portraitVC.removeFromParent()
            portraitViewController = nil
        }

        DDLogDebug("MainScreenViewController: deinit - all resources cleaned up")
    }

    // MARK: Internal

    enum WeatherDisplayMode {
        case detailed
        case forecast
    }

    // MARK: - Combine Publishers for PortraitView

    /// These allows us to send data from MainViewController to PortraitView
    let temperatureSubject = CurrentValueSubject<String?, Never>(nil)
    let locationSubject = CurrentValueSubject<String?, Never>(nil)
    let weatherIconSubject = CurrentValueSubject<UIImage?, Never>(nil)
    let todayWeatherArraySubject = CurrentValueSubject<
        [[String: String]], Never
    >([])
    let forecastWeatherArraySubject = CurrentValueSubject<
        [(String, String, String, UIImage, String)], Never
    >([])
    let carouselImageSubject = CurrentValueSubject<UIImage?, Never>(nil)
    let eventListArraySubject = CurrentValueSubject<
        [(String, String, String, String, String, Bool)], Never
    >([])
    let isTodayActivityPresentSubject = CurrentValueSubject<Bool, Never>(false)
    let statusIndicatorArraySubject = CurrentValueSubject<
        [(String, String, Int)], Never
    >([])
    let siteLogoSubject = CurrentValueSubject<UIImage?, Never>(
        UIImage(named: "SS")
    )
    let isSaraAlertPresentedSubject = CurrentValueSubject<Bool, Never>(false)
    let isClockPresentedSubject = CurrentValueSubject<Bool, Never>(false)
    let clockMessageSubject = CurrentValueSubject<String?, Never>(nil)
    let isRadioPlayingSubject = CurrentValueSubject<Bool, Never>(false)
    let isNarrationPlayingSubject = CurrentValueSubject<Bool, Never>(false)
    let scrollableTextSubject = CurrentValueSubject<String, Never>("")
    let customDesignSubject = CurrentValueSubject<Int, Never>(0)
    let customFontNameSubject = CurrentValueSubject<String, Never>(
        "Avenir Next"
    )
    let customFontSizeSubject = CurrentValueSubject<String, Never>("50")
    let currentCarouselHasAudioSubject = CurrentValueSubject<Bool, Never>(false)
    let isNetworkDownSubject = CurrentValueSubject<Bool, Never>(false)

    // SARA Alert publishers
    let saraAlertHeaderSubject = CurrentValueSubject<String, Never>("ALERT")
    let saraAlertMessageSubject = CurrentValueSubject<String, Never>(
        "Important information about your facility"
    )
    let saraAlertFooterSubject = CurrentValueSubject<String, Never>(
        "Please stand by for more information"
    )
    let saraAlertBorderColorSubject = CurrentValueSubject<String, Never>(
        "#000000"
    )
    let saraAlertBorderWidthSubject = CurrentValueSubject<CGFloat, Never>(10.0)
    let saraAlertFlashingSubject = CurrentValueSubject<Bool, Never>(false)
    let saraAlertFlashColorSubject = CurrentValueSubject<String, Never>(
        "#FFFF00"
    )
    let saraAlertBodyBackgroundColorSubject = CurrentValueSubject<
        String, Never
    >("#FFFFFF")
    let saraAlertBodyTextColorSubject = CurrentValueSubject<String, Never>(
        "#000000"
    )
    let saraAlertHeaderBackgroundColorSubject = CurrentValueSubject<
        String, Never
    >("#FFFFFF")
    let saraAlertHeaderTextColorSubject = CurrentValueSubject<String, Never>(
        "#000000"
    )
    let saraAlertHeaderFontSizeSubject = CurrentValueSubject<CGFloat, Never>(
        40.0
    )
    let saraAlertHeaderFontStyleSubject = CurrentValueSubject<String, Never>(
        "bold"
    )
    let saraAlertFooterBackgroundColorSubject = CurrentValueSubject<
        String, Never
    >("#FFFFFF")
    let saraAlertFooterTextColorSubject = CurrentValueSubject<String, Never>(
        "#000000"
    )
    let saraAlertFooterFontSizeSubject = CurrentValueSubject<CGFloat, Never>(
        18.0
    )
    let saraAlertFooterFontStyleSubject = CurrentValueSubject<String, Never>("")
    let saraAlertBodyFontSizeSubject = CurrentValueSubject<CGFloat, Never>(24.0)
    let saraAlertBodyFontStyleSubject = CurrentValueSubject<String, Never>("")
    let saraAlertHasRichTextSubject = CurrentValueSubject<Bool, Never>(false)
    let saraAlertBodyTextComponentsSubject = CurrentValueSubject<
        [PortraitViewModel.BodyTextComponent], Never
    >([])

    let headerTimeSubject = CurrentValueSubject<String, Never>("")
    let headerDateSubject = CurrentValueSubject<String, Never>("")

    let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)

    /// Main screen layout
    @IBOutlet var backgroundImageView: UIImageView!
    @IBOutlet var backgroundMaskView: UIView!
    @IBOutlet var mainScreenContentView: UIView!
    @IBOutlet var centerContentView: UIView!

    /// Header
    @IBOutlet var headerView: UIView!

    /// Date and time
    @IBOutlet var todayTime: UILabel!
    @IBOutlet var todayDate: UILabel!

    var updateDateTimer: Timer?
    var isUpdateDateTimerGotSycned = false

    /// Footer
    @IBOutlet var footerView: UIView!

    /// Scrolling textView
    @IBOutlet var scrollableTextView: UIScrollView!
    @IBOutlet var scrollTextContainerView: UIView!
    var scrollTextToRadioConstraint: NSLayoutConstraint?
    var scrollTextToFooterConstraint: NSLayoutConstraint?
    var scrollableTextLabel: UILabel!
    var scrollbarTimer: Timer?
    var scrollTextOffset: CGFloat = 0

    /// Radio
    @IBOutlet var radioPlayingIcon: UIImageView!
    @IBOutlet var radioView: UIView!
    var radioConnection = RadioPlayerController()

    @IBOutlet var carousalShadowView: UIView!

    var carousalImageTimer: Timer?
    var startTime = ""
    var endTime = ""

    /// SARA Alert view
    @IBOutlet var saraAlertView: UIView!
    @IBOutlet var saraAlertHeaderView: UIView!
    @IBOutlet var saraAlertBodyView: UIView!
    @IBOutlet var saraAlertFooterView: UIView!

    var saraAlertFlashTimer: Timer?
    var saraAlertAudioPlayer: AVAudioPlayer!
    /// Used to swap between the two colors
    var saraAlertFlashFlag = false
    /// this will be combination of two colors to make the flash work
    var saraAlertFlashOptions = [CGColor]()
    /// loading view
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!

    /// Weather View
    /// tag = 1
    @IBOutlet var fourDayWeatherTable: UITableView!
    /// tag = 2
    @IBOutlet var detailedWeatherTable: UITableView!

    @IBOutlet var fourDayWeatherView: UIView!
    @IBOutlet var detailedWeatherView: UIView!

    var weatherDisplayTimer: Timer?
    var weatherDisplayMode: WeatherDisplayMode = .detailed

    @IBOutlet var weatherTableHeaderView: UIView!

    // Events

    @IBOutlet var eventListView: UIView!
    @IBOutlet var eventListTable: UITableView!

    var multiCalendarStatus = false
    var eventAnimationTimer: Timer?
    var onGoingEventScheduleTimer: Timer?
    var portraitEventUpdateWorkItem: DispatchWorkItem?
    var scheduledEventTimings = [Date]()
    var eventYOffset = 0
    var eventDataCount = 0

    var isPortraitModeEnabled = false

    var portraitViewController: PortraitViewController?

    // StatusIndicator

    @IBOutlet var statusIndicatorSuperView: UIView!

    /// revisit
    @IBOutlet var statusIndicatorCollectionView: UICollectionView!

    @IBOutlet var StatusIndicatorPageControlSuperView: UIView!

    var StatusIndicatorPageControl = UIPageControl()

    var statusAnimationTimer: Timer?
    var statusContentTextOffset: CGFloat = 0
    /// Registration gesture
    @IBOutlet var registrationGesture: UIButton!

    /// Network down indicator label
    @IBOutlet var networkDownIndication: UILabel!

    @IBOutlet var customHomePage: UIView!

    @IBOutlet var labelForTime: UILabel!

    @IBOutlet var labelForDate: UILabel!
    @IBOutlet var customclock: UIView!
    @IBOutlet var ClockShow: UIView!

    @IBOutlet var showDescription: UIView!
    var clockView: ClockViews?
    var saraAlertTriggered = 0
    var showClockTriggered = 0
    var isClockTimerGotSycned = false
    var setClockTimer: Timer?
    var displayTimer: Timer?
    var clockStartTime = ""
    var clockEndTime = ""

    var managedContext: NSManagedObjectContext!

    var narrationAudioPlayer = NarrationAudioPlayer.sharedInstance()

    var lastNetworkState: Bool = true

    var isFirstNetworkNotification: Bool = true

    @IBOutlet var showDetails: UILabel!

    // Center View

    /// Carousal View
    @IBOutlet var carousalView: UIImageView!

    /// Weather
    @IBOutlet var todayWeatherIcon: UIImageView!

    @IBOutlet var todayWeathertemp: UILabel!

    @IBOutlet var todayWeatherLocation: UILabel!

    /// Site logo
    @IBOutlet var headerSiteLogo: UIImageView!

    var actualUIType = 1 // Store the actual UI type from server (catieTvType)

    // MARK: - Advertisement Carousel Properties

    /// Array to store normal slides (carouselType = 0)
    var normalSlidesArray = [(Data, Int, String, String)]()

    /// Array to store advertisement slides (carouselType = 2)
    var advertisementSlidesArray = [(Data, Int, String, String)]()

    /// Counter to track normal slides shown (for 4:1 advertisement ratio)
    var normalSlideCount = 0

    /// Current index for advertisement slides
    var advertisementIndex = 0

    /// Current index for normal slides progression
    var normalIndex = 0

    var isNarrationPausedDueToClock: Bool {
        get {
            narrationClockQueue.sync {
                _isNarrationPausedDueToClock
            }
        }
        set {
            narrationClockQueue.async(flags: .barrier) { [weak self] in
                self?._isNarrationPausedDueToClock = newValue
            }
        }
    }

    var scrollableText = "" {
        didSet {
            scrollableTextSubject.send(scrollableText)
        }
    }

    var carousalImageArray = [(Data, Int, String, String)]() {
        didSet {
            updateCarouselAudioStatus()
        }
    }

    var imageCount = 0 {
        didSet {
            updateCarouselAudioStatus()
        }
    }

    /// Used to handle the other modules which uses the audio when sara alerts presented
    var isSaraAlertPresented: Bool {
        get {
            saraAlertQueue.sync {
                _isSaraAlertPresented
            }
        }
        set {
            saraAlertQueue.async(flags: .barrier) { [weak self] in
                guard let self else {
                    return
                }

                _isSaraAlertPresented = newValue
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    isSaraAlertPresentedSubject.send(newValue)
                }
            }
        }
    }

    /// Check whether the carousel narration is playing or not
    var isNarrationPlaying: Bool {
        get {
            narrationPlayingQueue.sync {
                _isNarrationPlaying
            }
        }
        set {
            narrationPlayingQueue.async(flags: .barrier) { [weak self] in
                guard let self else {
                    return
                }

                _isNarrationPlaying = newValue
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    isNarrationPlayingSubject.send(newValue)
                    updateCarouselAudioStatus() // Update audio status based on narration
                }
            }
        }
    }

    var todayWeatherArray = [[String: String]]() {
        didSet {
            todayWeatherArraySubject.send(todayWeatherArray)
        }
    }

    var forecastWeatherArray = [(String, String, String, UIImage, String)]() {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                forecastWeatherArraySubject.send(forecastWeatherArray)
            }
        }
    }

    /// Start time, End time, Event Name, Event Calendar Name,Even Description, onGoing event flag
    var eventListArray = [(String, String, String, String, String, Bool)]() {
        didSet {
            eventListArraySubject.send(eventListArray)
        }
    }

    var isTodayActivityPresent = false {
        didSet {
            isTodayActivityPresentSubject.send(isTodayActivityPresent)
        }
    }

    var statusIndicatorArray = [(String, String, Int)]() {
        didSet {
            statusIndicatorArraySubject.send(statusIndicatorArray)

            // Reset scroll position when status indicator array changes
            DispatchQueue.main.async { [weak self] in
                self?.statusIndicatorCollectionView?.setContentOffset(.zero, animated: false)
            }
        }
    }

    var customDesign = 0 {
        didSet {
            customDesignSubject.send(customDesign)
        }
    }

    var tvRadioFlag = 1 { // 1 = show radio, 0 = hide radio
        didSet {
            // Handle radio playback when flag changes
            handleRadioPlaybackControl()
        }
    }

    var isClockPresented: Bool = false {
        didSet {
            isClockPresentedSubject.send(isClockPresented)
        }
    }

    var customFontName = "Avenir Next" {
        didSet {
            customFontNameSubject.send(customFontName)
        }
    }

    var customFontSize = "100" {
        didSet {
            customFontSizeSubject.send(customFontSize)
        }
    }

    var isCarouselOnlyModeActive: Bool {
        get {
            carouselOnlyModeQueue.sync {
                _isCarouselOnlyModeActive
            }
        }
        set {
            carouselOnlyModeQueue.async(flags: .barrier) { [weak self] in
                self?._isCarouselOnlyModeActive = newValue
            }
        }
    }

    // MARK: - Main View Controller Lifecycle

    // MARK: - View controller life cycle delegate

    override func viewDidLoad() {
        super.viewDidLoad()

        NarrationAudioPlayer.sharedInstance().delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNarrationDidStart),
            name: .narrationDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNarrationDidFailToLoad),
            name: .narrationDidFailToLoad,
            object: nil
        )
        fourDayWeatherTable?.accessibilityIdentifier = "FourDay Weather Table"
        detailedWeatherTable?.accessibilityIdentifier = "Detailed Weather Table"
        statusIndicatorCollectionView?.accessibilityIdentifier =
            "Status Indicator Collection"
        eventListTable?.accessibilityIdentifier = "Event List Table"
        scrollableTextView?.accessibilityIdentifier = "Scrollable Text"

        // Store reference to the original scroll text constraint for UI type 6 adjustments
        if let scrollTextContainer = scrollTextContainerView,
           let footerView
        {
            // Search through all constraints to find the scroll text to radio view constraint
            for constraint in footerView.constraints {
                // Check both directions of the constraint relationship
                if (constraint.firstItem === scrollTextContainer && constraint.secondAttribute == .trailing) ||
                    (constraint.secondItem === scrollTextContainer && constraint.firstAttribute == .trailing)
                {
                    scrollTextToRadioConstraint = constraint
                    DDLogDebug("MainScreen: Found scroll text constraint for UI type 6 adjustments")
                    break
                }
            }

            if scrollTextToRadioConstraint == nil {
                DDLogDebug("MainScreen: Warning - Could not find scroll text trailing constraint")
            }
        }

        // Force first network notification to be processed by setting to opposite state
        // This is to ensure that the first notification is processed correctly when network is not available when during app launch
        lastNetworkState = !isNetworkReachable
        // Initialize the network status publisher
        isNetworkDownSubject.send(!isNetworkReachable)

        SwiftTryCatch.try {
            DDLogDebug(
                "---------------Mainscreen : Mainscreen ViewDidLoad Called---------------"
            )

            if self.managedContext == nil {
                self.managedContext =
                    (UIApplication.shared.delegate as? AppDelegate)?
                        .persistentContainer
                        .newBackgroundContext()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in - \(String(describing: exception))"
            )
        }

        // Configure corner radius for header and footer views
        configureCornerRadius()
        eventListView.clipsToBounds = true
    }

    override func viewWillAppear(_: Bool) {
        super.viewWillAppear(true)

        SwiftTryCatch.try {
            DDLogDebug(
                "---------------Mainscreen : Mainscreen ViewWillAppear Called---------------"
            )

            self.registrationGesture?.isUserInteractionEnabled = true // opening registration page from home view
            self.registrationGesture?.addGestureRecognizer(
                self.generateGestureRecogniser()
            )

            self.radioConnection.mainViewdelegate = self

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.networkStatusChanged(notification:)),
                name: NSNotification.Name(
                    rawValue: "networkReachabilityChanged"
                ),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.serverStatusChanged(notification:)),
                name: NSNotification.Name(
                    rawValue: "serverReachabilityChanged"
                ),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.refreshCarousalImages),
                name: NSNotification.Name(rawValue: "refreshCarousalModel"),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.refreshSiteLogoModel),
                name: NSNotification.Name(rawValue: "refreshSiteLogoModel"),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.refreshWeatherModel),
                name: NSNotification.Name(rawValue: "refreshWeatherModel"),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.refreshSaraAlertModel),
                name: NSNotification.Name(rawValue: "refreshSaraAlertModel"),
                object: nil
            )
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in viewWillAppear - \(String(describing: exception))"
            )
        }
    }

    override func viewDidAppear(_: Bool) {
        super.viewDidAppear(true)

        SwiftTryCatch.try {
            DDLogDebug(
                "---------------Mainscreen : Mainscreen ViewDidAppear Called ---------------"
            )
            adjustMainScreenLayout()

            // Store the original UI Type 1 constraints from storyboard
            storeOriginalUITypeConstraints()

            if (UserDefaults.standard.value(forKey: "roomNumber") as? String
                == nil)
                || (UserDefaults.standard.value(forKey: "roomNumber") as? String
                    == "")
            {
                DDLogDebug(
                    "Mainscreen : No room number registered, presenting registration page"
                )
                ApplicationState().resetUserDefaults()
                presentRegistrationPage()
            } else {
                domainAddress =
                    UserDefaults.standard.value(forKey: "domainAddress")
                        as? String
                roomNo =
                    UserDefaults.standard.value(forKey: "roomNumber") as? String
                userID =
                    UserDefaults.standard.value(forKey: "userId") as? String

                DDLogDebug(
                    "Mainscreen : Room number already registered, domain - \(String(describing: domainAddress)),roomNo - \(String(describing: roomNo)), userId - \(String(describing: userID))"
                )

                DDLogDebug("Mainscreen : Schedule UpdateDate Timer")

                self.scheduleUpdateDateTimer()

                // Data fetching
                viewUpdateHandlerConnection.mainViewdelegate = self
                viewUpdateHandlerConnection.managedObjectContext =
                    self.managedContext

                if updateUIFromLocalData {
                    DDLogDebug(
                        "Mainscreen : Check Local data available and update UI"
                    )
                    viewUpdateHandlerConnection.updateUI()
                } else {
                    updateUIFromLocalData = true
                }

                DDLogDebug("Mainscreen: Check for Reachability")

                if isNetworkReachable {
                    socketConnection.mainViewdelegate = self
                    self.isNetworkDownSubject.send(false)
                    socketConnection.startSocketConnection(
                        withAddress: domainAddress!,
                        roomNumber: roomNo!
                    )
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        DDLogDebug("Mainscreen : Network down")
                        networkDownIndication?.isHidden = false
                        isNetworkDownSubject.send(true)
                    }
                }

                DDLogDebug("Mainscreen : Initiate pushLogFiles Timer")

                if pushLogFilesTimer.isValid {
                    pushLogFilesTimer.invalidate()
                }

                // sending logs to server for every 12 hrs once
                pushLogFilesTimer = Timer.scheduledTimer(
                    timeInterval: 43200,
                    target: self,
                    selector: #selector(self.sendLogsToServer),
                    userInfo: nil,
                    repeats: true
                )
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in viewDidAppear - \(String(describing: exception))"
            )
        }
    }

    override func viewWillDisappear(_: Bool) {
        SwiftTryCatch.try {
            DDLogDebug(
                "---------------Mainscreen : viewWillDisappear Called---------------"
            )

            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(
                    rawValue: "networkReachabilityChanged"
                ),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(
                    rawValue: "serverReachabilityChanged"
                ),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(rawValue: "refreshCarousalModel"),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(rawValue: "refreshSiteLogoModel"),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(rawValue: "refreshWeatherModel"),
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name(rawValue: "refreshSaraAlertModel"),
                object: nil
            )

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in viewWillDisappear - \(String(describing: exception))"
            )
        }
    }

    func isInPortraitMode() -> Bool {
        isPortraitModeActive
    }

    func presentPortraitView() {
        SwiftTryCatch.try {
            DDLogDebug("MainScreen: Presenting portrait view")

            self.isPortraitModeActive = true

            self.prepareForPortraitMode()

            // Hide main content views
            self.mainScreenContentView?.isHidden = true
            self.centerContentView?.isHidden = true

            // Remove any existing portrait view controller
            if let existingVC = portraitViewController {
                existingVC.willMove(toParent: nil)
                existingVC.view.removeFromSuperview()
                existingVC.removeFromParent()
            }

            // Create new portrait view controller
            self.portraitViewController = PortraitViewController()
            guard let portraitVC = self.portraitViewController else {
                return
            }

            portraitVC.setMainViewController(self) // Set the main controller reference

            // Explicitly resend current network status to ensure it's properly reflected in portrait mode
            let currentNetworkStatus = !isNetworkReachable
            self.isNetworkDownSubject.send(currentNetworkStatus)
            DDLogDebug(
                "MainScreen: Explicitly sending network status on portrait transition: isNetworkDown=\(currentNetworkStatus)"
            )

            // Explicitly refresh events data for the portrait view
            DDLogDebug(
                "MainScreen: Explicitly updating events data for portrait view"
            )
            eventListArraySubject.send(eventListArray)
            isTodayActivityPresentSubject.send(isTodayActivityPresent)

            // Explicitly resend scroll text for portrait view
            DDLogDebug("MainScreen: Explicitly sending scroll text for portrait view: '\(scrollableText)'")
            scrollableTextSubject.send(scrollableText)

            if let timeText = self.todayTime?.text,
               let dateText = self.todayDate?.text
            {
                self.headerTimeSubject.send(timeText)
                self.headerDateSubject.send(dateText)
            }

            // Add as child view controller - ensure it's added after other views are hidden
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                addChild(portraitVC)
                view.addSubview(portraitVC.view)

                // Configure the view controller for portrait orientation
                portraitVC.view.translatesAutoresizingMaskIntoConstraints =
                    false

                // Size constraints - create a container with swapped width/height dimensions
                NSLayoutConstraint.activate([
                    portraitVC.view.centerXAnchor.constraint(
                        equalTo: view.centerXAnchor
                    ),
                    portraitVC.view.centerYAnchor.constraint(
                        equalTo: view.centerYAnchor
                    ),
                    portraitVC.view.widthAnchor.constraint(
                        equalTo: view.heightAnchor
                    ),
                    portraitVC.view.heightAnchor.constraint(
                        equalTo: view.widthAnchor
                    ),
                ])

                portraitVC.view.transform = CGAffineTransform(
                    rotationAngle: CGFloat(-90) * .pi / 180
                )

                // Complete the child view controller relationship
                portraitVC.didMove(toParent: self)

                // Log success
                DDLogDebug("MainScreen: Portrait view presented successfully")
            }
        } catch: { exception in
            DDLogDebug(
                "MainScreen: Exception in presentPortraitView - \(String(describing: exception))"
            )
        }
    }

    func prepareForPortraitMode() {
        DDLogDebug(
            "MainScreen: Stopping all animation timers for portrait mode"
        )

        stopAllTimers()
    }

    @objc func handleNarrationDidStart(_ notification: Notification) {
        // Extract the slideIndex from the notification
        let slideIndex = notification.userInfo?["slideIndex"] as? Int ?? -1

        // Only respond if this is for the current slide
        if slideIndex != imageCount {
            DDLogDebug(
                "MainScreen: Ignoring narration start for different slide (current: \(imageCount), notification for: \(slideIndex))"
            )
            return
        }

        // Pause or stop the radio playback immediately
        radioConnection.isRadioPausedDueToNarration = true
        radioConnection.radioPlayingStatus = false
        isRadioPlayingSubject.send(false)
        radioConnection.stopRadio()
        DispatchQueue.main.async {
            self.updateRadioIcon(status: false, isNetworkDown: false)
        }
        DDLogDebug(
            "MainScreen: Narration started for slide \(slideIndex), radio will be stopped if running"
        )

        if saraAlertTriggered == 1 {
            narrationAudioPlayer.stopCurrentAudio()
            DDLogDebug("MainScreen: Sara alert is showing stopping narration")
        }
    }

    /// Add this method to handle the new notification:
    @objc func handleNarrationDidFailToLoad(_ notification: Notification) {
        // Extract the slideIndex from the notification
        let slideIndex = notification.userInfo?["slideIndex"] as? Int ?? -1

        DDLogDebug(
            "MainScreen: Received narration failure notification for slide \(slideIndex), current slide is \(imageCount)"
        )

        // Only respond if this is for the current slide
        if slideIndex != imageCount {
            DDLogDebug(
                "MainScreen: Ignoring narration failure for different slide (current: \(imageCount), notification for: \(slideIndex))"
            )
            return
        }

        DDLogDebug(
            "MainScreen: Narration failed to load for slide \(slideIndex), resuming carousel with default duration"
        )
        isNarrationPlaying = false

        // Calculate default duration
        let safeCarouselArray = getCarouselImagesCopy()
        let defaultDuration =
            !safeCarouselArray.isEmpty
                && safeCarouselArray.indices.contains(imageCount)
                ? Double(safeCarouselArray[imageCount].1) : 10.0
        let finalDuration = max(defaultDuration, 3.0)

        // Check if the network is the cause of the failure
        if !isNetworkReachable {
            DDLogDebug(
                "MainScreen: Scheduling next slide with default duration of \(finalDuration) seconds despite network being down"
            )
            scheduleNextSlide(with: finalDuration)
            return
        }

        // Network is available but narration still failed (could be server error, file missing, etc.)
        DDLogDebug(
            "MainScreen: Scheduling next slide with default duration of \(finalDuration) seconds due to narration failure"
        )
        scheduleNextSlide(with: finalDuration)
        let radioAllowedByServer = radioConnection.isRadioPlaybackAllowedByServer()

        // Resume radio if it was paused due to narration
        if radioAllowedByServer, radioConnection.isRadioPausedDueToNarration,
           !radioConnection.radioPlayingStatus, !isSaraAlertPresented
        {
            radioConnection.isRadioPausedDueToNarration = false
            radioConnection.radioPlayingStatus = true
            isRadioPlayingSubject.send(true)
            radioConnection.playRadio()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                updateRadioIcon(status: true, isNetworkDown: false)
            }
            DDLogDebug(
                "MainScreen: Radio resumed as narration failed to load and network is available"
            )
        } else if radioConnection.isRadioPausedDueToNarration {
            DDLogDebug("MainScreen: Radio resume blocked - radioPlayingStatus: \(String(describing: radioConnection.radioPlayingStatus)), isSaraAlertPresented: \(isSaraAlertPresented), serverPlayingStatus: \(String(describing: radioAllowedByServer))")
        }
    }

    /// Callback to set the isNarrationPlaying flag
    /// Runs when the narration is finished playing
    func narrationAudioPlayerDidFinishPlaying() {
        DDLogDebug("Mainscreen: Narration finished playing for slide \(imageCount)")

        isNarrationPlaying = false

        // Invalidate the existing timer (which includes buffer time) and advance immediately
        if carousalImageTimer?.isValid == true {
            carousalImageTimer?.invalidate()
        }

        DDLogDebug("Mainscreen: Advancing to next slide after narration finished")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.advanceToNextSlide()
        }
    }

    // MARK: - Date and time

    func scheduleUpdateDateTimer() {
        SwiftTryCatch.try {
            self.updateDateTimer?.invalidate()

            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            dateFormatter.dateFormat = "h:mm a"
            let currentTime = dateFormatter.string(from: date)
            dateFormatter.dateFormat = "EEEE"

            var currentDay = "\(dateFormatter.string(from: date))"
            dateFormatter.dateFormat = "MMM d, yyyy"
            currentDay =
                currentDay + "\r" + "\(dateFormatter.string(from: date))"

            dateFormatter.dateFormat = "EEEE, MMM d, yyyy"
            let currentDate = dateFormatter.string(from: date)

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                todayTime?.text = currentTime
                todayDate?.text = currentDate

                labelForTime?.text = currentTime
                labelForTime?.textColor = UIColor(named: "Header_Text")

                labelForDate?.text = currentDay
                labelForDate?.textColor = UIColor(named: "Header_Text")
                labelForDate?.adjustsFontSizeToFitWidth = true

                headerTimeSubject.send(currentTime)
                headerDateSubject.send(currentDate)
            }

            self.isUpdateDateTimerGotSycned = false

            let calendar = Calendar.current
            let seconds = calendar.component(.second, from: date)
            let interval = Double(60 - seconds) // calculating firing time interval to sync up with device timer.
            self.updateDateTimer = Timer.scheduledTimer(
                timeInterval: interval,
                target: self,
                selector: #selector(self.updateDate),
                userInfo: nil,
                repeats: true
            )

            DDLogDebug("Mainscreen : Timer scheduled")
            self.checkTimeForSyncData(currentTime: currentTime)
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in scheduleUpdateDateTimer - \(String(describing: exception))"
            )
        }
    }

    @objc func updateDate() {
        SwiftTryCatch.try {
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")

            dateFormatter.dateFormat = "h:mm a"
            let currentTime = dateFormatter.string(from: date)
            dateFormatter.dateFormat = "EEEE"

            var currentDay = "\(dateFormatter.string(from: date))"
            dateFormatter.dateFormat = "MMM d, yyyy"
            currentDay =
                currentDay + "\r" + "\(dateFormatter.string(from: date))"

            dateFormatter.dateFormat = "EEEE, MMM d, yyyy"
            let currentDate = dateFormatter.string(from: date)

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                todayTime?.text = currentTime
                todayDate?.text = currentDate

                labelForTime?.text = currentTime
                labelForTime?.textColor = UIColor(named: "Header_Text")

                labelForDate?.text = currentDay
                labelForDate?.textColor = UIColor(named: "Header_Text")
                labelForDate?.adjustsFontSizeToFitWidth = true

                headerTimeSubject.send(currentTime)
                headerDateSubject.send(currentDate)
            }

            DDLogDebug("Mainscreen : Check updateDate Timer got synced or not")

            // resetting timer based on synced status
            if !self.isUpdateDateTimerGotSycned {
                self.updateDateTimer?.invalidate()
                self.isUpdateDateTimerGotSycned = true
                self.updateDateTimer = Timer.scheduledTimer(
                    timeInterval: 60,
                    target: self,
                    selector: #selector(self.updateDate),
                    userInfo: nil,
                    repeats: true
                )
                DDLogDebug("Mainscreen : New Timer scheduled")
            }

            self.checkTimeForSyncData(currentTime: currentTime)

            DDLogDebug("Mainscreen : Current Date Updated")
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in updateDate - \(String(describing: exception))"
            )
        }
    }

    func checkTimeForSyncData(currentTime: String) {
        SwiftTryCatch.try {
            if currentTime == "2:00 AM" || currentTime == "2:00" {
                if !syncDataForAllModulesNotifyReceived {
                    DDLogDebug(
                        "Mainscreen : Sync Data Notify Received - \(syncDataForAllModulesNotifyReceived)"
                    )
                    socketConnection.getTVStatus()
                } else {
                    DDLogDebug(
                        "Mainscreen : Sync Data Notify Received - \(syncDataForAllModulesNotifyReceived), so reset the status"
                    )
                    syncDataForAllModulesNotifyReceived = false
                    callForDailyDataSync = true
                    socketConnection.getTVStatus()
                }
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in checkTimeForSyncData - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Clock and Message

    func showClock(message: String) {
        SwiftTryCatch.try {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                clockView?.removeFromSuperview()

                let text = message

                showDetails?.font = UIFont(
                    name: customFontName,
                    size: CGFloat((customFontSize as NSString).doubleValue)
                )
                showDetails?.text = text
                showDetails?.textColor = UIColor.white

                clockMessageSubject.send(message)

                customclock?.backgroundColor = .black
                customclock?.alpha = 0.9

                setClockTimer?.invalidate()

                displayTimer?.invalidate()

                let date = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")

                dateFormatter.dateFormat = "EEEE, MMM d, yyyy"
                isClockTimerGotSycned = false

                let calendar = Calendar.current
                let seconds = calendar.component(.second, from: date)
                let interval = Double(60 - seconds) // calculating firing time interval to sync up with device timer.

                DDLogDebug(
                    "Mainscreen : Clock Timer will be scheduled in  \(interval)"
                )

                customclock?.isHidden = true
                showDetails?.isHidden = true

                if interval == 60.0 {
                    clockView = ClockViews(
                        frame: ClockShow?.frame
                            ?? CGRect(x: 0, y: 0, width: 1160, height: 1080)
                    )
                    ClockShow?.addSubview(clockView!)
                    clockView?.frame = ClockShow.bounds
                    showDescription?.addSubview(showDetails)
                    isClockPresented = true
                    // self.enableClock()
                    // self.clockData.secondsAnimation.duration = CFTimeInterval(interval)
                } else {
                    DDLogDebug(
                        "Mainscreen : Timer to show clock in next minute initiated."
                    )
                    displayTimer = Timer.scheduledTimer(
                        timeInterval: interval,
                        target: self,
                        selector: #selector(clockTimerForDisplay),
                        userInfo: nil,
                        repeats: false
                    )
                }

                setClockTimer = Timer.scheduledTimer(
                    timeInterval: interval,
                    target: self,
                    selector: #selector(clockTimer),
                    userInfo: nil,
                    repeats: true
                )
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in showClock - \(String(describing: exception))"
            )
        }
    }

    @objc func clockTimerForDisplay() {
        displayTimer?.invalidate()

        clockView = ClockViews(
            frame: ClockShow?.frame
                ?? CGRect(x: 0, y: 0, width: 1160, height: 1080)
        )

        ClockShow?.addSubview(clockView!)
        clockView?.frame = ClockShow.bounds
        showDescription?.addSubview(showDetails)
        isClockPresented = true
        // self.enableClock()
    }

    @objc func clockTimer() {
        SwiftTryCatch.try {
            // Create formatters for 12-hour input and 24-hour comparison (like carousel)
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "h:mm a"
            inputFormatter.locale = Locale(identifier: "en_US_POSIX")
            inputFormatter.amSymbol = "AM"
            inputFormatter.pmSymbol = "PM"

            let comparisonFormatter = DateFormatter()
            comparisonFormatter.locale = Locale(identifier: "en_US_POSIX")
            comparisonFormatter.dateFormat = "HH:mm:ss"

            // Parse 12-hour format input and convert to 24-hour format for comparison
            let startClock12 = inputFormatter.date(from: self.clockStartTime)
            let endClock12 = inputFormatter.date(from: self.clockEndTime)

            let startClockTime = startClock12 != nil ? comparisonFormatter.date(from: comparisonFormatter.string(from: startClock12!)) : nil
            let endclockTime = endClock12 != nil ? comparisonFormatter.date(from: comparisonFormatter.string(from: endClock12!)) : nil
            let currentTime = comparisonFormatter.date(from: comparisonFormatter.string(from: Date()))

            if startClockTime != nil {
                if endclockTime != nil {
                    if currentTime != nil {
                        if currentTime! >= startClockTime!,
                           currentTime! < endclockTime!
                        {
                            self.enableClock()
                        } else {
                            DDLogDebug(
                                "Mainscreen :current time is not in clock's scheduled time so hiding clock"
                            )
                            self.disableClock()
                        }
                        if !self.isClockTimerGotSycned {
                            self.setClockTimer?.invalidate()
                            self.isClockTimerGotSycned = true
                            self.setClockTimer = Timer.scheduledTimer(
                                timeInterval: TimeInterval(60),
                                target: self,
                                selector: #selector(self.clockTimer),
                                userInfo: nil,
                                repeats: true
                            )
                        }

                        if currentTime! == endclockTime! {
                            self.setClockTimer?.invalidate()
                            self.isClockTimerGotSycned = false
                            self.showClockTriggered = 0
                            DDLogDebug("Mainscreen : Clock Timer invalidate")
                            DDLogDebug(
                                "Mainscreen : current time is not in the clock's scheduled time,no need to show clock"
                            )
                            self.clockView?.removeFromSuperview()
                        }

                    } else {
                        DDLogDebug(
                            "Mainscreen : can not convert clock current Time in given format"
                        )
                        self.setClockTimer?.invalidate()
                        self.isClockTimerGotSycned = false
                        self.showClockTriggered = 0
                        DDLogDebug("Mainscreen : Clock Timer invalidate")
                        self.clockView?.removeFromSuperview()
                    }

                } else {
                    DDLogDebug(
                        "Mainscreen : can not convert clock end Time in given format"
                    )
                    self.setClockTimer?.invalidate()
                    self.isClockTimerGotSycned = false
                    self.showClockTriggered = 0
                    DDLogDebug("Mainscreen : Clock Timer invalidate")
                    self.clockView?.removeFromSuperview()
                }

            } else {
                DDLogDebug(
                    "Mainscreen : can not convert clock start Time in given format "
                )
                self.setClockTimer?.invalidate()
                self.isClockTimerGotSycned = false
                self.showClockTriggered = 0
                DDLogDebug("Mainscreen : Clock Timer invalidate")
                self.clockView?.removeFromSuperview()
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in clockTimer - \(String(describing: exception))"
            )
        }
    }

    func enableClock() {
        SwiftTryCatch.try {
            // Only pause carousel if not already paused for clock
            if !self.isNarrationPausedDueToClock {
                DDLogDebug("Mainscreen: Pausing carousel for clock display")
                self.isNarrationPausedDueToClock = true
                self.narrationAudioPlayer.stopCurrentAudio()

                // Stop carousel timer to prevent it from firing during clock display
                self.carousalImageTimer?.invalidate()
                DDLogDebug("Mainscreen: Carousel timer stopped for clock display")
            }

            let radioAllowedByServer = self.radioConnection.isRadioPlaybackAllowedByServer()

            // resuming radio when clock is showing
            if radioAllowedByServer,!self.radioConnection.radioPlayingStatus,
               !self.isSaraAlertPresented

            {
                self.radioConnection.isRadioPausedDueToNarration = false
                self.radioConnection.radioPlayingStatus = true
                self.isRadioPlayingSubject.send(true)
                self.radioConnection.playRadio()
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    updateRadioIcon(status: true, isNetworkDown: false)
                }
                DDLogDebug(
                    "Mainscreen : Radio resumed as clock is showing on screen"
                )
            } else {
                DDLogDebug(
                    "MainScreen: Clock radio resume blocked - radioPlayingStatus: \(String(describing: self.radioConnection.radioPlayingStatus)), isSaraAlertPresented: \(self.isSaraAlertPresented), serverPlayingStatus: \(String(describing: radioAllowedByServer))"
                )
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                if saraAlertTriggered == 0, displayTimer?.isValid != true {
                    customclock?.isHidden = false
                    showDetails?.isHidden = false
                    isClockPresented = true
                    DDLogDebug(
                        "Mainscreen :current time is in clock's scheduled time so displaying clock"
                    )
                } else {
                    if saraAlertTriggered == 1 {
                        DDLogDebug(
                            "Mainscreen : Unable to show clock due to SARA Alert"
                        )
                    }
                }
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in enableClock - \(String(describing: exception))"
            )
        }
    }

    func disableClock() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen: Disabling clock")

            // Only restart carousel if it was paused for clock
            let shouldRestartCarousel = self.isNarrationPausedDueToClock

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                customclock?.isHidden = true
                showDetails?.isHidden = true
                isClockPresented = false

                // Restart carousel on main thread
                if shouldRestartCarousel {
                    DDLogDebug("Mainscreen: Resuming carousel after clock disabled")
                    self.isNarrationPausedDueToClock = false

                    // Restart carousel - matching the SARA alert dismissal pattern
                    let safeCarouselArray = self.getCarouselImagesCopy()
                    if !safeCarouselArray.isEmpty {
                        self.carousalImageTimer?.invalidate()
                        DDLogDebug("Mainscreen: Carousel timer restart after clock disabled")
                        self.changeCarousalImage()
                    } else {
                        DDLogDebug("Mainscreen: Carousel array is empty, cannot restart after clock")
                    }
                }
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen: Exception in disableClock - \(String(describing: exception))"
            )
        }
    }

    func getClockFeed() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Get clock details from clock connection")
            clockConnection.mainViewdelegate = self
            clockConnection.getClockData()

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getClockFeed - \(String(describing: exception))"
            )
        }
    }

    func clockSuccessResponse() {
        SwiftTryCatch.try {
            self.safelyShowActivityIndicator(true)
            self.isLoadingSubject.send(true)

            DDLogDebug(
                "Mainscreen : Loading view enabled at clockSuccessResponse"
            )

            self.setClockTimer?.invalidate()

            DDLogDebug("Mainscreen : Fetching clock Details")
            let clockAndMessage = DataHandler().fetchData(
                "Clock",
                self.managedContext
            )

            if clockAndMessage?.count ?? 0 > 0 {
                self.managedContext.performAndWait {
                    let data = clockAndMessage?[0] as? Clock

                    // Extract data safely within the Core Data context
                    let statusFlag = data?.statusFlag ?? 0
                    let startTime = data?.startTime ?? ""
                    let endTime = data?.endTime ?? ""
                    let message = data?.message ?? ""

                    // Then dispatch UI updates to the main queue
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        if statusFlag == 1 {
                            clockStartTime = startTime
                            clockEndTime = endTime
                            showClockTriggered = 1
                            showClock(message: message)
                        } else {
                            clockFailureResponse(message: "Hide Clock")
                            showClockTriggered = 0
                        }
                    }
                }

            } else {
                self.clockFailureResponse(
                    message: "No clock data available in Db"
                )
                self.showClockTriggered = 0
            }

            self.safelyShowActivityIndicator(false)
            self.isLoadingSubject.send(false)

            OngoingAPICallDict.shared.setObject(key: "Clock", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Clock") == true {
                DDLogDebug("Mainscreen : Process Pending Clock Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Clock",
                    value: false
                )
                self.getClockFeed()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in ClockSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    func clockFailureResponse(message: String, isNetworkError: Bool = false) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Clock failure response \(message)")
            if !isNetworkError {
                self.setClockTimer?.invalidate()
                self.displayTimer?.invalidate()
                self.showClockTriggered = 0

                self.disableClock()
            }
            OngoingAPICallDict.shared.setObject(key: "Clock", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Clock") == true {
                DDLogDebug("Mainscreen : Process Pending Clock Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Clock",
                    value: false
                )
                self.getClockFeed()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in customHomePageFailureResponse - \(String(describing: exception))"
            )
        }
    }

    // MARK: - CustomHomePage

    func getCustomHomePage() {
        SwiftTryCatch.try {
            DDLogDebug(
                "Mainscreen : Get Custom Home Page Data from customHomePageConnection"
            )
            //            viewUpdateHandlerConnection.mainViewdelegate = self
            customHomePageConnection.mainViewdelegate = self
            customHomePageConnection.getCustomHomePageData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getWeather - \(String(describing: exception))"
            )
        }
    }

    func customHomePageSuccessResponse(_ customHomePage: [CustomHomePage]?) {
        SwiftTryCatch.try {
            self.safelyShowActivityIndicator(true)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                isLoadingSubject.send(true)
                todayTime?.isHidden = true
                todayDate?.isHidden = true
            }

            DDLogDebug(
                "Mainscreen : Loading view enabled at customHomePageSuccessResponse"
            )
            DDLogDebug("Mainscreen : Fetching customHomePage Details")

            // Check if data exists
            if !(customHomePage?.isEmpty ?? true) {
                // Variables to store data extracted from Core Data
                var tvStatus = 1
                var targetType = 1
                var fontType = "Avenir Next"
                var fontSize = "50"
                var radioFlag = 1

                // Extract all necessary data within Core Data context
                self.managedContext.performAndWait {
                    guard let data = customHomePage?[0] else {
                        return
                    }

                    tvStatus = Int(data.tvStatus)
                    targetType = Int(data.catieTvType)
                    fontType = data.catieTvFontType ?? "Avenir Next"
                    fontSize = data.catieTvFontSize ?? "50"
                    radioFlag = Int(data.tvRadioFlag)
                }

                // Perform all UI operations on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    // Handle tvStatus = 0 case (device not registered)
                    if tvStatus == 0 {
                        if pushLogFilesTimer.isValid {
                            pushLogFilesTimer.invalidate()
                        }
                        if pingServerTimer.isValid {
                            pingServerTimer.invalidate()
                        }
                        if pingTimer.isValid {
                            pingTimer.invalidate()
                        }

                        socketConnection.cancelAllURLSessionDataTask()
                        radioFeedFailureResponse(
                            message:
                            " No room is registered so not saving radio response"
                        )
                        stopHomeViewUpdates()
                        socketConnection.closeSocketConnection()
                        deleteLocalStorage()
                        ApplicationState().resetUserDefaults()
                        presentRegistrationPage()
                        return
                    }

                    // Store previous UI type before updating
                    let previousUIType = actualUIType
                    let previousRadioFlag = tvRadioFlag

                    // Skip UI switching if same UI type, except for radio flag changes on UI types 5 & 6, or initial setup
                    if previousUIType == targetType, hasCompletedInitialUISetup {
                        if targetType == 5 || targetType == 6, previousRadioFlag != radioFlag {
                            // UI type 5 or 6 with radio flag change - proceed with update
                            DDLogDebug("Mainscreen: Same UIType \(targetType) but radio flag changed from \(previousRadioFlag) to \(radioFlag) - updating radio display")
                        } else {
                            // Same UI type and same radio flag (or not UI type 5/6) - skip
                            DDLogDebug("Mainscreen: Skipping UI switch - same UIType \(targetType) with same radio flag \(radioFlag)")
                            // Restore time/date labels that were hidden at start of customHomePageSuccessResponse
                            todayTime?.isHidden = false
                            todayDate?.isHidden = false
                            return
                        }
                    } else {
                        if hasCompletedInitialUISetup {
                            DDLogDebug("Mainscreen: UI switching from \(previousUIType) to \(targetType)")
                        } else {
                            DDLogDebug("Mainscreen: Performing initial UI setup for UIType \(targetType)")
                        }
                    }

                    // Update UI properties first
                    actualUIType = targetType
                    tvRadioFlag = radioFlag
                    customFontName = fontType
                    customFontSize = fontSize

                    // Switch UI
                    handleUITypeSwitch(targetType: targetType, radioFlag: radioFlag)
                }
            } else {
                // No custom home page data
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    customDesign = 0
                    DDLogDebug(
                        "Mainscreen : No CustomHomePage data available in Core data"
                    )
                }
            }

            // Stop loading indicator after processing
            self.safelyShowActivityIndicator(false)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                isLoadingSubject.send(false)
            }

            // Handle pending API calls
            OngoingAPICallDict.shared.setObject(key: "CustomPage", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "CustomPage")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending CustomPage Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "CustomPage",
                    value: false
                )
                self.getCustomHomePage()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in customHomePageSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    func dismissPortrait() {
        guard let pvc = portraitViewController else {
            return
        }

        pvc.willMove(toParent: nil)
        pvc.view.removeFromSuperview()
        pvc.removeFromParent()
        portraitViewController = nil

        // Show your UIKit content again:
        mainScreenContentView.isHidden = false
        centerContentView.isHidden = false

        // Reset the portrait mode flag BEFORE restarting timers
        isPortraitModeActive = false

        // Restart UIKit animations and timers
        resumeUIKitMode()

        DDLogDebug("MainScreen: Switched back to UIKit and restarted timers")
    }

    func resumeUIKitMode() {
        DDLogDebug("MainScreen: Resuming UIKit mode and restarting animations")

        // Force an immediate date update
        updateDate()

        // If events are present, restart their animations
        if isTodayActivityPresent {
            updateOnGoingEvents()

            let currentEvents = getEventListCopy()
            let animateCheck =
                multiCalendarStatus
                    ? currentEvents.count > 3 : currentEvents.count > 4

            eventYOffset = -10
            eventDataCount = 0

            if animateCheck {
                // Use events without duplication
                updateEventList(currentEvents)

                eventListTable?.contentOffset.y = CGFloat(eventYOffset)
                eventListTable?.reloadData()

                // Only show eventListView if not in carousel-only mode
                if !isCarouselOnlyModeActive {
                    eventListView?.isHidden = false
                }

                DDLogDebug("MainScreen: Restarting event animation timer")

                // Only start animation timer if not in carousel-only mode
                if !isCarouselOnlyModeActive {
                    eventAnimationTimer = Timer.scheduledTimer(
                        timeInterval: 15,
                        target: self,
                        selector: #selector(animateTodayEvents),
                        userInfo: nil,
                        repeats: true
                    )
                }
            } else {
                eventListTable?.contentOffset.y = CGFloat(eventYOffset)
                eventListTable?.reloadData()

                // Only show eventListView if not in carousel-only mode
                if !isCarouselOnlyModeActive {
                    eventListView?.isHidden = false
                }
            }
        }

        // Restart weather display cycle
        if !isTodayActivityPresent {
            // Reset to detailed view when starting the timer
            weatherDisplayMode = .detailed
            updateWeatherDisplay()

            DDLogDebug("MainScreen: Restarting weather display timer")
            weatherDisplayTimer = Timer.scheduledTimer(
                timeInterval: 10,
                target: self,
                selector: #selector(updateWeatherDisplay),
                userInfo: nil,
                repeats: true
            )
        }

        // Restart status indicators if present
        let currentStatusIndicators = getStatusIndicatorsCopy()
        if !currentStatusIndicators.isEmpty {
            statusIndicatorCollectionView?.reloadData()

            if Int(ceil(CGFloat(currentStatusIndicators.count) / 2.0)) > 1 {
                statusContentTextOffset = 0.0

                // Use the dedicated method to avoid double timer creation
                restartStatusAnimationTimer()
                DDLogDebug("MainScreen: Restarted status animation timer via dedicated method")
            }
        }

        // Restart carousel if needed
        let safeCarouselArray = getCarouselImagesCopy()
        if !safeCarouselArray.isEmpty, !isSaraAlertPresented, !isNarrationPausedDueToClock {
            carousalImageTimer?.invalidate()

            DDLogDebug("MainScreen: Restarting carousel")
            changeCarousalImage()
        }

        // Restore scrollable text if present - dispatch to next run loop to ensure layout is complete
        if !scrollableText.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                setScrollableView()
            }
        }

        // Add this code to restart SARA alert flash if needed
        if isSaraAlertPresented, saraAlertTriggered == 1 {
            DDLogDebug("MainScreen: Restarting SARA alert flash")
            // Check if flash was enabled via the flag in saraAlertData
            let flashEnabled = saraAlertFlashOptions.count >= 2
            if flashEnabled, saraAlertFlashTimer?.isValid != true {
                saraAlertFlashTimer = Timer.scheduledTimer(
                    timeInterval: TimeInterval(1),
                    target: self,
                    selector: #selector(updateAlertFlash),
                    userInfo: nil,
                    repeats: true
                )
            }
        }
    }

    func customHomePageFailureResponse(
        message: String,
        isNetworkError: Bool = false
    ) {
        SwiftTryCatch.try {
            DDLogDebug(
                "Mainscreen : custom homepage failure response \(message)"
            )
            if !isNetworkError {
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    todayTime?.isHidden = false
                    todayDate?.isHidden = false
                    customHomePage?.isHidden = true
                }
                self.customDesign = 0
            }
            OngoingAPICallDict.shared.setObject(key: "CustomPage", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "CustomPage")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending CustomPage Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "CustomPage",
                    value: false
                )
                self.getCustomHomePage()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in customHomePageFailureResponse - \(String(describing: exception))"
            )
        }
    }

    func customHomePageNewUI() {
        SwiftTryCatch.try {
            // Stop weather display timer to prevent weather views from reappearing
            weatherDisplayTimer?.invalidate()
            DDLogDebug("Mainscreen : Stopped weather display timer for UIType 2")

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                detailedWeatherView?.isHidden = true
                fourDayWeatherView?.isHidden = true
                eventListView?.isHidden = true
                customHomePage?.isHidden = false

                DDLogDebug("Mainscreen : UIType 2 - Hidden weather views and shown custom home page")
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in customHomePageNewUI - \(String(describing: exception))"
            )
        }
    }

    func carouselOnlyUI(showRadio: Bool = true) {
        SwiftTryCatch.try {
            // Set carousel-only mode flag BEFORE UI changes
            self.isCarouselOnlyModeActive = true

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                // Hide all UI elements except carousel to create carousel-only layout
                detailedWeatherView?.isHidden = true
                fourDayWeatherView?.isHidden = true
                eventListView?.isHidden = true
                statusIndicatorSuperView?.isHidden = true
                StatusIndicatorPageControlSuperView?.isHidden = true
                customHomePage?.isHidden = true

                // Keep header, footer and carousel visible
                headerView?.isHidden = false
                footerView?.isHidden = false
                carousalView?.isHidden = false
                carousalShadowView?.isHidden = false

                // Show time and date in the header for carousel-only layout
                todayTime?.isHidden = false
                todayDate?.isHidden = false

                // Handle radio visibility and scroll text constraints
                if showRadio {
                    // Show radio and use original constraints
                    radioPlayingIcon?.isHidden = false
                    radioView?.backgroundColor = UIColor.clear
                    if let footerConstraint = scrollTextToFooterConstraint {
                        footerConstraint.isActive = false
                        scrollTextToFooterConstraint = nil
                    }
                    scrollTextToRadioConstraint?.isActive = true
                } else {
                    // Hide radio and extend scroll text
                    radioPlayingIcon?.isHidden = true
                    radioView?.backgroundColor = UIColor.clear

                    if let scrollTextContainer = scrollTextContainerView,
                       let footerView
                    {
                        scrollTextToRadioConstraint?.isActive = false

                        if let existingConstraint = scrollTextToFooterConstraint {
                            existingConstraint.isActive = false
                            scrollTextToFooterConstraint = nil
                        }

                        scrollTextToFooterConstraint = scrollTextContainer.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -60)
                        scrollTextToFooterConstraint?.isActive = true
                    }
                }

                // Expand carousel to take full available width
                activateCarouselFullWidthLayout()

                // Expand SARA Alert to take full available width (same as carousel)
                activateSaraAlertFullWidthLayout()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in carouselOnlyUI - \(String(describing: exception))"
            )
        }
    }

    func restoreNormalUI(for targetUIType: Int = 0) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : restoreNormalUI - entered SwiftTryCatch.try block")
            // Turn off carousel-only mode flag BEFORE UI changes
            self.isCarouselOnlyModeActive = false

            // Restore constraints immediately - we're likely already on main thread
            DDLogDebug("Mainscreen : About to call restoreCarouselToUIType(\(targetUIType)) from restoreNormalUI")
            // For UI Types 1 and 2, both should use the same carousel layout (non-full-width)
            let uiTypeForCarousel = (targetUIType == 1 || targetUIType == 2) ? 1 : targetUIType
            restoreCarouselToUIType(uiTypeForCarousel)

            // Restore SARA Alert to original layout
            restoreSaraAlertOriginalLayout()

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    DDLogDebug("Mainscreen : restoreNormalUI - self is nil, returning early")
                    return
                }

                DDLogDebug("Mainscreen : restoreNormalUI - inside DispatchQueue.main.async, self is valid")

                // Use target UI type if provided, otherwise fall back to actual UI type
                let uiTypeToRestore = targetUIType > 0 ? targetUIType : actualUIType

                // Restore UI elements based on target UI type
                if uiTypeToRestore == 1 {
                    // UIType 1: Show events when available, otherwise show weather
                    if isTodayActivityPresent {
                        // Events are available - show events, hide weather
                        eventListView?.isHidden = false
                        detailedWeatherView?.isHidden = true
                        fourDayWeatherView?.isHidden = true
                        DDLogDebug("Mainscreen : UIType 1 - Showing events (events available)")
                    } else {
                        // No events - show weather, hide events
                        eventListView?.isHidden = true
                        detailedWeatherView?.isHidden = false
                        fourDayWeatherView?.isHidden = false
                        DDLogDebug("Mainscreen : UIType 1 - Showing weather (no events)")
                    }
                    statusIndicatorSuperView?.isHidden = false
                    StatusIndicatorPageControlSuperView?.isHidden = false
                    customHomePage?.isHidden = true

                    // Restart timers for UIType 1
                    if weatherDisplayTimer?.isValid != true {
                        // Reset to detailed view when starting the timer
                        weatherDisplayMode = .detailed
                        weatherDisplayTimer = Timer.scheduledTimer(
                            timeInterval: 10,
                            target: self,
                            selector: #selector(updateWeatherDisplay),
                            userInfo: nil,
                            repeats: true
                        )
                        DDLogDebug("Mainscreen : Restarted weather display timer for UIType 1")
                    }
                    if eventAnimationTimer?.isValid != true {
                        eventAnimationTimer = Timer.scheduledTimer(
                            timeInterval: 15,
                            target: self,
                            selector: #selector(animateTodayEvents),
                            userInfo: nil,
                            repeats: true
                        )
                        DDLogDebug("Mainscreen : Restarted event animation timer for UIType 1")
                    }
                } else if uiTypeToRestore == 2 {
                    // UIType 2: No events/weather scroll, shows time date layout with status indicators
                    detailedWeatherView?.isHidden = true
                    fourDayWeatherView?.isHidden = true
                    eventListView?.isHidden = true
                    statusIndicatorSuperView?.isHidden = false // UI Type 2 shows status indicators
                    StatusIndicatorPageControlSuperView?.isHidden = false // UI Type 2 shows page control
                    customHomePage?.isHidden = false
                    DDLogDebug("Mainscreen : UIType 2 - Time date layout with status indicators (no events/weather scroll)")

                    // Stop all timers for UIType 2
                    weatherDisplayTimer?.invalidate()
                    DDLogDebug("Mainscreen : Stopped weather timer for UIType 2")
                    eventAnimationTimer?.invalidate()
                    DDLogDebug("Mainscreen : Stopped event timer for UIType 2")
                } else if uiTypeToRestore == 5 || uiTypeToRestore == 6 {
                    // UIType 5 & 6: Landscape wide / Portrait padded - hide detailed weather, events and status indicators
                    detailedWeatherView?.isHidden = true
                    fourDayWeatherView?.isHidden = true
                    eventListView?.isHidden = true
                    statusIndicatorSuperView?.isHidden = true
                    StatusIndicatorPageControlSuperView?.isHidden = true
                    customHomePage?.isHidden = true
                    DDLogDebug("Mainscreen : UIType \(uiTypeToRestore) - Carousel-focused mode (detailed weather, events and status indicators hidden)")

                    // Stop event and status indicator timers for UIType 5 & 6
                    eventAnimationTimer?.invalidate()
                    DDLogDebug("Mainscreen : Stopped event timer for UIType \(uiTypeToRestore)")
                    statusAnimationTimer?.invalidate()
                    DDLogDebug("Mainscreen : Stopped status indicator timer for UIType \(uiTypeToRestore)")
                } else {
                    // Other UI types: Default behavior
                    detailedWeatherView?.isHidden = false
                    fourDayWeatherView?.isHidden = false
                    eventListView?.isHidden = false
                    statusIndicatorSuperView?.isHidden = false
                    StatusIndicatorPageControlSuperView?.isHidden = false
                    customHomePage?.isHidden = true
                }

                // Ensure header, footer and carousel remain visible
                headerView?.isHidden = false
                footerView?.isHidden = false
                carousalView?.isHidden = false
                carousalShadowView?.isHidden = false

                // Restore radio icon visibility based on tvRadioFlag
                radioPlayingIcon?.isHidden = (tvRadioFlag == 0)
                radioView?.backgroundColor = UIColor.clear // Restore original background

                // Restore scroll text constraints based on radio visibility
                if tvRadioFlag == 1 {
                    // Radio is visible - use original radio constraint
                    if let footerConstraint = scrollTextToFooterConstraint {
                        footerConstraint.isActive = false
                        scrollTextToFooterConstraint = nil
                    }
                    scrollTextToRadioConstraint?.isActive = true
                } else {
                    // Radio is hidden - maintain footer constraint for UIType 1
                    if let scrollTextContainer = scrollTextContainerView,
                       let footerView
                    {
                        // Deactivate radio constraint
                        scrollTextToRadioConstraint?.isActive = false

                        // Clean up existing footer constraint to prevent conflicts
                        if let existingConstraint = scrollTextToFooterConstraint {
                            existingConstraint.isActive = false
                            scrollTextToFooterConstraint = nil
                        }

                        // Create new footer constraint for UIType 1 with radio hidden
                        scrollTextToFooterConstraint = scrollTextContainer.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -60)
                        scrollTextToFooterConstraint?.isActive = true
                    }
                }

                // Reset carousel content mode to proper aspect fit for normal UI types
                if uiTypeToRestore != 5, uiTypeToRestore != 6 {
                    carousalView?.contentMode = .scaleAspectFit
                }

                // Force comprehensive layout update for all UI elements
                view.setNeedsLayout()
                view.layoutIfNeeded()

                // Force layout update for specific container views in proper order
                centerContentView?.setNeedsLayout()
                centerContentView?.layoutIfNeeded()

                // Update header and footer first (they affect overall layout)
                headerView?.setNeedsLayout()
                headerView?.layoutIfNeeded()
                footerView?.setNeedsLayout()
                footerView?.layoutIfNeeded()

                carousalView?.contentMode = .scaleToFill

                // Then update carousel (central component)
                carousalView?.setNeedsLayout()
                carousalView?.layoutIfNeeded()
                carousalShadowView?.setNeedsLayout()
                carousalShadowView?.layoutIfNeeded()

                // Finally update other content views
                detailedWeatherView?.setNeedsLayout()
                detailedWeatherView?.layoutIfNeeded()
                fourDayWeatherView?.setNeedsLayout()
                fourDayWeatherView?.layoutIfNeeded()
                eventListView?.setNeedsLayout()
                eventListView?.layoutIfNeeded()
                statusIndicatorSuperView?.setNeedsLayout()
                statusIndicatorSuperView?.layoutIfNeeded()

                // Force a final overall layout pass
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    view.setNeedsLayout()
                    view.layoutIfNeeded()
                    DDLogDebug("Mainscreen : Completed final layout pass after UI restoration")
                }

                DDLogDebug(
                    "Mainscreen : Normal UI layout and carousel constraints restored with forced layout update"
                )
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in restoreNormalUI - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Registration gesture

    func generateGestureRecogniser() -> UITapGestureRecognizer {
        var returnGestureRecogniser = UITapGestureRecognizer()

        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Gesture Recogniser initiated")
            let tapGesturerecogniser = UITapGestureRecognizer(
                target: self,
                action: #selector(self.handleTap)
            )
            tapGesturerecogniser.numberOfTapsRequired = 5
            returnGestureRecogniser = tapGesturerecogniser
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in generateGestureRecogniser - \(String(describing: exception))"
            )
        }
        return returnGestureRecogniser
    }

    @objc func handleTap() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Gesture recognizer pressed")
            presentRegistrationPage()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in handleTap - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Weather view delegates

    @objc func refreshWeatherModel() {
        DDLogDebug("Mainscreen : Refresh weather Data")
        weatherSuccessResponse()
    }

    func getWeather() {
        SwiftTryCatch.try {
            DDLogDebug(
                "Mainscreen : Get weather details from weather connection"
            )
            weatherConnection.mainViewdelegate = self
            weatherConnection.getWeatherData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getWeather - \(String(describing: exception))"
            )
        }
    }

    func weatherSuccessResponse() {
        SwiftTryCatch.try {
            self.safelyShowActivityIndicator(true)
            self.isLoadingSubject.send(true)
            DDLogDebug(
                "Mainscreen : Loading view enabled at weatherSuccessResponse"
            )

            DDLogDebug("Mainscreen : Fetching weather Details")

            self.managedContext.performAndWait { [self] in
                let detailedWeatherData = DataHandler().fetchData(
                    "DetailedWeather",
                    managedContext
                )
                let forecastWeatherData = DataHandler().fetchData(
                    "ForeCastWeather",
                    managedContext
                )
                let weatherData = DataHandler().fetchData(
                    "Weather",
                    managedContext
                )

                if weatherData?.count ?? 0 > 0 {
                    for i in weatherData! {
                        let data = i as? Weather
                        let todayWeatherImage = UIImage(
                            data: data?.weatherIcon ?? Data(),
                            scale: 1.0
                        )
                        let location = data?.city ?? ""
                        let temperature = data?.temperature ?? ""

                        DispatchQueue.main.async { [weak self] in
                            guard let self else {
                                return
                            }

                            todayWeatherIcon?.image = todayWeatherImage?.withRenderingMode(.alwaysTemplate)
                            todayWeatherIcon?.tintColor = UIColor(named: "Header_Text")
                            todayWeatherLocation?.text = " " + location
                            todayWeathertemp?.text =
                                temperature.replacingOccurrences(
                                    of: "degree",
                                    with: "°"
                                )

                            // Explicitly send updates through the publishers
                            weatherIconSubject.send(todayWeatherImage)
                            locationSubject.send(location)
                            temperatureSubject.send(
                                temperature.replacingOccurrences(
                                    of: "degree",
                                    with: "°"
                                )
                            )
                        }
                        DDLogDebug("Mainscreen :Weather icon totalImageSize - \(String(format: "%.5f", Float(data?.weatherIcon?.count ?? 0) / 1_000_000))MB")
                    }

                    if customDesign == 0 {
                        todayWeatherArray = [[String: String]]()

                        if detailedWeatherData?.count ?? 0 > 0 {
                            for i in detailedWeatherData! {
                                let data = i as? DetailedWeather

                                todayWeatherArray.append([
                                    "Feels Like": data?.feelsLike?
                                        .replacingOccurrences(
                                            of: "degree",
                                            with: "°"
                                        ) ?? "",
                                ])
                                todayWeatherArray.append([
                                    "Pressure": data?.pressure ?? "",
                                ])
                                todayWeatherArray.append([
                                    "Humidity": data?.humidity ?? "",
                                ])
                                todayWeatherArray.append([
                                    "Wind": data?.wind ?? "",
                                ])
                                todayWeatherArray.append([
                                    "Visibility": data?.visibilty ?? "",
                                ])
                                todayWeatherArray.append([
                                    "Sunrise": data?.sunRise ?? "",
                                ])
                                todayWeatherArray.append([
                                    "Sunset": data?.sunSet ?? "",
                                ])
                            }
                            DDLogDebug(
                                "Mainscreen : Detailed Weather Array initiated - \(todayWeatherArray)"
                            )

                        } else {
                            DDLogDebug(
                                "Mainscreen : Detailed Weather data is not available in local storage"
                            )
                        }

                        var newForecastArray = [
                            (String, String, String, UIImage, String)
                        ]()
                        var totalImageSize = 0

                        if let forecastData = forecastWeatherData
                            as? [ForeCastWeather], !forecastData.isEmpty
                        {
                            for data in forecastData {
                                // Create a local image object that isn't tied to self
                                let iconData = data.weatherIcons ?? Data()
                                let weatherImage =
                                    UIImage(data: iconData, scale: 1.0)
                                        ?? UIImage()

                                // Create the tuple with nil coalescing
                                let forecastItem = (
                                    data.day ?? "",
                                    (data.high ?? "").replacingOccurrences(
                                        of: "degree",
                                        with: "°"
                                    ),
                                    (data.low ?? "").replacingOccurrences(
                                        of: "degree",
                                        with: "°"
                                    ),
                                    weatherImage,
                                    data.des ?? ""
                                )

                                // Add to temporary array
                                newForecastArray.append(forecastItem)
                                totalImageSize += iconData.count
                            }

                            // Assign the completed array all at once
                            forecastWeatherArray = newForecastArray

                            DDLogDebug("Mainscreen : Forecast Weather Array initiated - \(newForecastArray.count) items - totalImageSize - \(String(format: "%.5f", Float(totalImageSize) / 1_000_000))MB")
                        } else {
                            // Just set an empty array
                            forecastWeatherArray = []
                            DDLogDebug(
                                "Mainscreen : Forecast Weather data not available in local storage"
                            )
                        }

                        safelyShowActivityIndicator(false)
                        DispatchQueue.main.async { [weak self] in
                            guard let self else {
                                return
                            }

                            isLoadingSubject.send(false)
                            DDLogDebug(
                                "Mainscreen : Loading view disabled at weatherSuccessResponse count greater"
                            )

                            // Only reload detailed weather tables for UIType 1 (landscape with detailed weather views)
                            if actualUIType == 1 {
                                detailedWeatherTable?.reloadData()
                                fourDayWeatherTable?.reloadData()
                                DDLogDebug("Mainscreen : Reloaded detailed weather tables for UIType 1")
                            } else {
                                DDLogDebug("Mainscreen : Skipped detailed weather table reload for UIType \(actualUIType) (only UIType 1 uses landscape weather tables)")
                            }

                            DDLogDebug(
                                "Mainscreen : Check is there any Today Activities"
                            )

                            if !isTodayActivityPresent {
                                weatherDisplayTimer?.invalidate()

                                // Skip weather view management if in carousel-only mode (UI Types 5 & 6)
                                guard !isCarouselOnlyModeActive else {
                                    DDLogDebug(
                                        "Mainscreen : Skipping weather view management while in carousel-only mode (UI Types 5 & 6)"
                                    )
                                    return
                                }

                                DDLogDebug(
                                    "Mainscreen : Hide Weather Details Table"
                                )

                                fourDayWeatherView?.isHidden = true
                                detailedWeatherView?.isHidden = false
                                eventListView?.isHidden = true
                                // Reset to detailed view when starting the timer
                                weatherDisplayMode = .detailed
                                updateWeatherDisplay()
                                weatherDisplayTimer = Timer.scheduledTimer(
                                    timeInterval: 10,
                                    target: self,
                                    selector: #selector(
                                        updateWeatherDisplay
                                    ),
                                    userInfo: nil,
                                    repeats: true
                                )
                            }
                        }
                    } else {
                        // Handle customDesign != 0 case - ensure loading indicator is hidden
                        weatherDisplayTimer?.invalidate()
                        safelyShowActivityIndicator(false)
                        isLoadingSubject.send(false)
                        DDLogDebug("Mainscreen : Loading view disabled at weatherSuccessResponse customDesign != 0")
                    }

                } else {
                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at weatherSuccessResponse count lesser "
                    )
                    DDLogDebug("Mainscreen : No weather data on local storage")
                }
            }

            OngoingAPICallDict.shared.setObject(key: "Weather", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Weather") == true {
                DDLogDebug("Mainscreen : Process Pending Weather Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Weather",
                    value: false
                )
                self.getWeather()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in weatherSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    func weatherFailureResponse(message: String, isNetworkError: Bool = false) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Weather failure response \(message)")
            if !isNetworkError {
                self.weatherDisplayTimer?.invalidate()
                // handle when no event and weather available to present. (back to static icons)
                self.safelyShowActivityIndicator(false)
                self.isLoadingSubject.send(false)
                DDLogDebug(
                    "Mainscreen : Loading view disabled at weatherFailureResponse"
                )
            }

            OngoingAPICallDict.shared.setObject(key: "Weather", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Weather") == true {
                DDLogDebug("Mainscreen : Process Pending Weather Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Weather",
                    value: false
                )
                self.getWeather()
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in weatherFailureResponse - \(String(describing: exception))"
            )
        }
    }

    @objc func updateWeatherDisplay() {
        SwiftTryCatch.try {
            // Only proceed for UI Type 1 and when there are no events
            guard self.actualUIType == 1 else {
                DDLogDebug(
                    "MainScreen: Ignoring updateWeatherDisplay for UIType \(self.actualUIType) (only UIType 1 supports weather display toggle)"
                )
                self.weatherDisplayTimer?.invalidate()
                return
            }
            guard !self.isTodayActivityPresent else {
                DDLogDebug(
                    "MainScreen: Ignoring updateWeatherDisplay because events are present"
                )
                self.weatherDisplayTimer?.invalidate()
                return
            }

            DDLogDebug("Mainscreen : Update Weather Display")

            // Toggle between detailed and forecast views based on current mode
            switch self.weatherDisplayMode {
            case .detailed:
                DDLogDebug(
                    "Mainscreen : Switching to four days weather view"
                )
                self.detailedWeatherView?.isHidden = true
                self.fourDayWeatherView?.isHidden = false
                self.eventListView?.isHidden = true
                self.weatherDisplayMode = .forecast

            case .forecast:
                DDLogDebug(
                    "Mainscreen : Switching to detailed weather view"
                )
                self.detailedWeatherView?.isHidden = false
                self.fourDayWeatherView?.isHidden = true
                self.eventListView?.isHidden = true
                self.weatherDisplayMode = .detailed
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in updateWeatherDisplay - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Carousal view delegates

    @objc func refreshCarousalImages() {
        DDLogDebug("Mainscreen : Refresh Carousal Image Data")
        carousalImagesSuccessResponse()
    }

    func getCarousalImages() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Get Carousal Image Data")
            carousalImagesConnection.mainViewdelegate = self
            carousalImagesConnection.getCarousalData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getCarousalImages - \(String(describing: exception))"
            )
        }
    }

    func carousalImagesSuccessResponse() {
        SwiftTryCatch.try {
            self.safelyShowActivityIndicator(true)
            self.isLoadingSubject.send(true)
            DDLogDebug(
                "Mainscreen : Loading view enabled at CarousalImagesSuccessResponse"
            )

            DDLogDebug("Mainscreen : Fetching Carousal Image details")
            let carousalData = DataHandler().fetchData(
                "Carousal",
                self.managedContext
            )
            let carousalImageData = DataHandler().fetchData(
                "CarousalImages",
                self.managedContext
            )

            var totalImageSize = 0

            self.managedContext.performAndWait {
                if !(carousalData?.isEmpty ?? true) {
                    if carousalData?.count ?? 0 > 0,
                       carousalImageData?.count ?? 0 > 0
                    {
                        self.carousalImageArray = [
                            (Data, Int, String, String)
                        ]()

                        // Initialize advertisement arrays
                        self.normalSlidesArray = [(Data, Int, String, String)]()
                        self.advertisementSlidesArray = [(Data, Int, String, String)]()
                        self.normalSlideCount = 0
                        self.advertisementIndex = 0
                        self.normalIndex = 0

                        DDLogDebug(
                            "Mainscreen : Carousal Image Array initiated with advertisement support"
                        )
                        for i in 0 ..< (carousalImageData?.count ?? 0) {
                            let data = carousalImageData?[i] as? CarousalImages

                            if !(data?.carousalImage?.isEmpty ?? true) { // Adding image only when it has any downloaded data
                                let slideTuple: (Data, Int, String, String)

                                slideTuple = (
                                    data?.carousalImage ?? Data(),
                                    Int(data?.slotTime ?? 0),
                                    data?.imageName ?? "", data?.audioPath ?? ""
                                )

                                totalImageSize =
                                    totalImageSize
                                        + (data?.carousalImage?.count ?? 0)
                                // Separate slides based on carouselType
                                let carouselType = Int(data?.carouselType ?? 0)

                                if carouselType == 2 {
                                    // Advertisement slide
                                    self.advertisementSlidesArray.append(slideTuple)
                                    DDLogDebug("Mainscreen : Advertisement slide added - \(String(describing: data?.imageName))")
                                } else {
                                    // Normal or ingage slide (carouselType = 0, 1, or default)
                                    self.normalSlidesArray.append(slideTuple)
                                    DDLogDebug("Mainscreen : Normal slide added - \(String(describing: data?.imageName))")
                                }

                                // Still add to main array for backward compatibility
                                self.carousalImageArray.append(slideTuple)
                                DDLogDebug(
                                    "Mainscreen : Carousal Image Array Data append : \(i + 1) image - \(String(describing: data?.imageName)) and slotTime - \(String(describing: data?.slotTime)) and AudioPath \(String(describing: data?.audioPath))"
                                )
                            } else {
                                DDLogDebug(
                                    "Mainscreen : Carousal \(String(describing: data?.imageName)) received empty data"
                                )
                            }
                        }

                        for carousal in carousalData! {
                            let data = carousal as? Carousal
                            self.startTime = data?.startTime ?? ""
                            self.endTime = data?.endTime ?? ""
                        }

                        DDLogDebug(
                            "Mainscreen : Carousal startTime - \(self.startTime) and endTime - \(self.endTime) and totalImageSize - \(String(format: "%.5f", Float(totalImageSize) / 1_000_000))MB"
                        )

                        // Log advertisement carousel summary
                        DDLogDebug("Mainscreen: Advertisement Carousel Summary - Normal slides: \(self.normalSlidesArray.count), Advertisement slides: \(self.advertisementSlidesArray.count), Total slides: \(self.carousalImageArray.count)")

                        DDLogDebug("Mainscreen : Check for SARA Alert")
                        if !self.isSaraAlertPresented {
                            self.safelyShowActivityIndicator(false)
                            DispatchQueue.main.async { [weak self] in
                                guard let self else {
                                    return
                                }

                                isLoadingSubject.send(false)
                                DDLogDebug(
                                    "Mainscreen : Loading view disabled at CarousalImagesSuccessResponse count greater"
                                )

                                carousalImageTimer?.invalidate()
                                DDLogDebug(
                                    "Mainscreen : Check Carousal Image Array count"
                                )
                                if !carousalImageArray.isEmpty {
                                    imageCount = 0
                                    changeCarousalImage() // Start the regular carousel cycle
                                } else {
                                    DDLogDebug(
                                        "Mainscreen : No data from Carousal Image Array, inserting DummyCarousal"
                                    )
                                    presentDefaultSlide()
                                }
                            }
                        } else {
                            self.narrationAudioPlayer.stopCurrentAudio()
                            DDLogDebug(
                                "Mainscreen : SARA Alert already presented, so not refreshing the carousel view"
                            )
                        }
                    } else {
                        self.CarousalImagesFailureResponse(
                            message: "No carousal image found"
                        )
                        DDLogDebug(
                            "Mainscreen : No carousal image data on local storage"
                        )
                    }
                } else {
                    DDLogDebug("Mainscreen : No carousal data on local storage")
                }
            }

            self.safelyShowActivityIndicator(false)
            self.isLoadingSubject.send(false)

            OngoingAPICallDict.shared.setObject(key: "Carousal", value: false)

            if PendingAPICallRequestDict.shared.getValue(key: "Carousal")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending Carousal Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Carousal",
                    value: false
                )
                self.getCarousalImages()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in CarousalImagesSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    @objc func changeCarousalImage() {
        SwiftTryCatch.try {
            if self.isNarrationPausedDueToClock || self.isSaraAlertPresented {
                self.narrationAudioPlayer.stopCurrentAudio()
                if self.isNarrationPausedDueToClock {
                    DDLogDebug(
                        "Mainscreen : Clock is present, Carousel is paused"
                    )
                }
                if self.isSaraAlertPresented {
                    DDLogDebug(
                        "Mainscreen : SARA alert is present, Carousel is paused"
                    )
                }
                return
            }

            DDLogDebug("Mainscreen : Presenting Carousel slides")

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "HH:mm:ss"
            let startDate = dateFormatter.date(from: self.startTime)
            let endDate = dateFormatter.date(from: self.endTime)
            let currentDate = dateFormatter.date(
                from: dateFormatter.string(from: Date())
            )

            if let startDate, let endDate, let currentDate {
                if currentDate > startDate, currentDate < endDate {
                    DDLogDebug(
                        "Mainscreen : Time duration passed, check and update the slide"
                    )

                    let safeCarouselArray = self.getCarouselImagesCopy()
                    guard !safeCarouselArray.isEmpty,
                          safeCarouselArray.indices.contains(
                              self.imageCount
                          )
                    else {
                        DDLogDebug(
                            "Mainscreen : carousalImageArray is empty or index out of bounds"
                        )
                        self.presentDefaultSlide()
                        return
                    }

                    // Network is not available
                    if !isNetworkReachable {
                        self.handleOfflineCarouselUpdate()
                        return
                    }

                    //  Use cached image or load from data
                    let imageData = safeCarouselArray[self.imageCount].0
                    let carouselSlotTime = safeCarouselArray[self.imageCount].1
                    let carouselName = safeCarouselArray[self.imageCount].2
                    let audioURLString = safeCarouselArray[self.imageCount].3
                    let currentSlideIndex = self.imageCount

                    // Preload next slide in background
                    self.preloadNextCarouselSlide()

                    if imageData.isEmpty {
                        DDLogDebug(
                            "Mainscreen : Carousel image data not available"
                        )
                        self.presentDefaultSlide()
                        return
                    }

                    // Check cache first, otherwise create and cache
                    let cacheKey = NSString(string: carouselName)
                    let carouselImage: UIImage

                    if let cachedImage = imageCache.object(forKey: cacheKey) {
                        DDLogDebug(
                            "Mainscreen : Using cached image for \(carouselName)"
                        )
                        carouselImage = cachedImage
                        // Proceed directly to UI update with cached image
                        self.updateCarouselViewWithImage(
                            carouselImage,
                            name: carouselName,
                            hasAudio: !audioURLString.isEmpty
                        )
                    } else if let newImage = UIImage(
                        data: imageData,
                        scale: 1.0
                    ) {
                        DDLogDebug(
                            "Mainscreen : Creating new image for \(carouselName)"
                        )
                        carouselImage = newImage
                        // Cache the newly created image
                        self.imageCache.setObject(
                            carouselImage,
                            forKey: cacheKey
                        )
                        // Update UI with new image
                        self.updateCarouselViewWithImage(
                            carouselImage,
                            name: carouselName,
                            hasAudio: !audioURLString.isEmpty
                        )
                    } else {
                        DDLogDebug(
                            "Mainscreen : Failed to create image for \(carouselName)"
                        )
                        self.presentDefaultSlide()
                        return
                    }

                    // Handle audio narration
                    self.handleCarouselAudio(
                        audioURLString: audioURLString,
                        currentSlideIndex: currentSlideIndex,
                        carouselSlotTime: carouselSlotTime
                    )
                } else {
                    DDLogDebug(
                        "Mainscreen : Start and end time not in range, presenting default slide"
                    )
                    self.presentDefaultSlide()
                    self.handleOutOfTimeRangeRadio()
                }
            } else {
                DDLogDebug(
                    "Mainscreen : changeCarouselImage - Date conversion failed for start, end, or current date"
                )
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in changeCarousalImage - \(String(describing: exception))"
            )
        }
    }

    func CarousalImagesFailureResponse(
        message: String,
        isNetworkError: Bool = false
    ) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : carousal failure response \(message)")
            if !isNetworkError {
                self.carousalImageArray = [(Data, Int, String, String)]()
                // Also clear advertisement arrays on failure
                self.normalSlidesArray = [(Data, Int, String, String)]()
                self.advertisementSlidesArray = [(Data, Int, String, String)]()
                self.normalSlideCount = 0
                self.advertisementIndex = 0
                self.normalIndex = 0
                self.carousalImageTimer?.invalidate()
                self.safelyShowActivityIndicator(false)
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    isLoadingSubject.send(false)
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at CarousalImagesFailureResponse"
                    )

                    presentDefaultSlide()
                }
            }
            OngoingAPICallDict.shared.setObject(key: "Carousal", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Carousal")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending Carousal Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Carousal",
                    value: false
                )
                self.getCarousalImages()
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in CarousalImagesFailureResponse - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Header site logo

    @objc func refreshSiteLogoModel() {
        siteLogoSuccessResponse()
    }

    func getSiteLogo() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Get SiteLogo Details")
            siteLogoImageConnection.mainViewdelegate = self
            siteLogoImageConnection.getSiteLogoData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getSiteLogo - \(String(describing: exception))"
            )
        }
    }

    func siteLogoSuccessResponse() {
        SwiftTryCatch.try {
            self.safelyShowActivityIndicator(true)
            self.isLoadingSubject.send(true)
            DDLogDebug(
                "Mainscreen : Loading view enabled at siteLogoSuccessResponse"
            )

            DDLogDebug("Mainscreen : Fetching SiteLogo details")

            let rows = DataHandler().fetchData("SiteLogo", self.managedContext)

            self.managedContext.performAndWait {
                if rows?.count ?? 0 > 0 {
                    for i in rows! {
                        let logo = i as? SiteLogo

                        DDLogDebug("Mainscreen : Checking siteLogo Data")
                        if logo?.imageData?.count ?? 0 > 0 {
                            DDLogDebug(
                                "Mainscreen : Applying site logo to imageView"
                            )
                            let logoData = logo?.imageData
                            DispatchQueue.main.async { [weak self] in
                                guard let self else {
                                    return
                                }

                                let image = UIImage(data: logoData!, scale: 1.0)
                                headerSiteLogo?.image = image
                                siteLogoSubject.send(image)
                            }
                            DDLogDebug(
                                "Mainscreen : SiteLogo totalImageSize - \(String(format: "%.5f", Float(logoData?.count ?? 0) / 1_000_000))MB"
                            )
                        } else {
                            DispatchQueue.main.async { [weak self] in
                                guard let self else {
                                    return
                                }

                                let image = UIImage(named: "SS")
                                headerSiteLogo?.image = image
                                siteLogoSubject.send(image)
                                DDLogDebug(
                                    "Mainscreen : No Site Logo image data on local storage"
                                )
                            }
                        }
                    }

                } else {
                    DDLogDebug(
                        "Mainscreen : No Site Logo image data on local storage"
                    )
                    self.siteLogoFailureResponse(
                        message:
                        "Mainscreen : No Site Logo image data on local storage"
                    )
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at siteLogoSuccessResponse"
                    )
                    self.safelyShowActivityIndicator(false)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        isLoadingSubject.send(false)
                        let image = UIImage(named: "SS")
                        headerSiteLogo?.image = image
                        siteLogoSubject.send(image)
                    }
                }
            }
            self.safelyShowActivityIndicator(false)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                isLoadingSubject.send(false)
                DDLogDebug(
                    "Mainscreen : Loading view disabled at siteLogoSuccessResponse"
                )
            }

            OngoingAPICallDict.shared.setObject(key: "SiteLogo", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "SiteLogo")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending SiteLogo Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "SiteLogo",
                    value: false
                )
                self.getSiteLogo()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in siteLogoSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    func siteLogoFailureResponse(message: String, isNetworkError: Bool = false) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : siteLogo failure response \(message)")
            if !isNetworkError {
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    let image = UIImage(named: "SS")
                    headerSiteLogo?.image = image
                    siteLogoSubject.send(image)
                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at siteLogoFailureResponse"
                    )
                }
            }

            OngoingAPICallDict.shared.setObject(key: "SiteLogo", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "SiteLogo")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending SiteLogo Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "SiteLogo",
                    value: false
                )
                self.getSiteLogo()
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in siteLogoFailureResponse - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Radio Player delegates

    func getRadioFeed() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Get Radio Feed details")
            radioResponseConnection.mainViewdelegate = self
            radioResponseConnection.getRadioMetaData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getRadioFeed - \(String(describing: exception))"
            )
        }
    }

    func radioFeedSuccessResponse() {
        SwiftTryCatch.try {
            self.safelyShowActivityIndicator(true)
            self.isLoadingSubject.send(true)
            DDLogDebug(
                "Mainscreen : Loading view enabled at radioFeedSuccessResponse"
            )

            DDLogDebug("Mainscreen : Fetching Radio Feed details")
            self.managedContext.performAndWait {
                let radioFeedData = DataHandler().fetchData(
                    "Radio",
                    self.managedContext
                )
                DDLogDebug("Mainscreen : Checking Radio Feed Data")
                if radioFeedData?.count ?? 0 > 0 {
                    for radio in radioFeedData! {
                        let data = radio as? Radio

                        let radioURL = data?.radioFeed
                        // Always set radioFeedURL when valid data is available,
                        // so it's ready when radio resumes after narration/alerts
                        if let radioURL = radioURL, !radioURL.isEmpty {
                            self.radioConnection.radioFeedURL = radioURL
                        }
                        DDLogDebug("Mainscreen : Checking Reachability")
                        if isNetworkReachable {
                            DDLogDebug(
                                "Mainscreen : Check SARA Alert presented or not"
                            )
                            // Already SARA alert presented so just raise the playing flag
                            if self.radioConnection.isRadioPausedDueToNarration
                                || self.isNarrationPlaying
                                || self.radioConnection.isRadioPausedDueToAlerts
                                || self.isSaraAlertPresented
                            {
                                if self.radioConnection.isRadioPausedDueToAlerts
                                    || self.isSaraAlertPresented
                                {
                                    DDLogDebug(
                                        "Mainscreen : SARA Alert found, Stop Radio if it's playing"
                                    )
                                    // Check if radio is already stopped
                                    if data?.playingStatus == 0 {
                                        // Reset the flag
                                        self.radioConnection
                                            .isRadioPausedDueToAlerts = false
                                    } else {
                                        self.radioConnection
                                            .isRadioPausedDueToAlerts = true
                                    }
                                }
                                if self.radioConnection
                                    .isRadioPausedDueToNarration
                                    || self.isNarrationPlaying
                                {
                                    DDLogDebug(
                                        "Mainscreen : Narration is Playing, Stop Radio if it's playing"
                                    )
                                    // Check if radio is already stopped
                                    if data?.playingStatus == 0 {
                                        // Reset the flag
                                        self.radioConnection
                                            .isRadioPausedDueToNarration = false
                                        self.radioConnection
                                            .radioPlayingStatus = false
                                    } else {
                                        self.radioConnection
                                            .isRadioPausedDueToNarration = true
                                    }
                                    self.isRadioPlayingSubject.send(false)
                                }
                            } else {
                                DDLogDebug(
                                    "Mainscreen : No SARA Alert, Initiate Radio"
                                )
                                let radioAllowedByServer = self.radioConnection.isRadioPlaybackAllowedByServer()
                                let isActuallyPlaying = self.radioConnection.isRadioActuallyPlaying()
  
                                if radioAllowedByServer, radioURL != nil, radioURL != "" {
                                    // Start radio if not already playing
                                    if !isActuallyPlaying {
                                        DDLogDebug("Mainscreen : Play Radio - Server allowed and radio not currently playing")
                                        self.radioConnection.radioFeedURL = radioURL
                                        self.radioConnection.playRadio()
                                        self.isRadioPlayingSubject.send(true)
                                    } else {
                                        DDLogDebug("Mainscreen : Radio already playing - no action needed")
                                    }
                                } else {
                                    DDLogDebug(
                                        "Mainscreen : Stop Radio - radioAllowedByServer: \(radioAllowedByServer), radioPlayingStatus: \(String(describing: self.radioConnection.radioPlayingStatus)), radioURL: \(String(describing: radioURL)), AVPlayer Playing: \(isActuallyPlaying)"
                                    )
                                    self.radioConnection.stopRadio()
                                    self.isRadioPlayingSubject.send(false)
                                    DispatchQueue.main.async { [weak self] in
                                        guard let self else {
                                            return
                                        }

                                        radioPlayingIcon?.image = UIImage(
                                            named: "Radio_Off"
                                        )
                                    }
                                }
                            }

                        } else {
                            DispatchQueue.main.async { [weak self] in
                                guard let self else {
                                    return
                                }

                                DDLogDebug(
                                    "Mainscreen : No Reachability, Radio_Down"
                                )
                                updateRadioIcon(status: false, isNetworkDown: true)
                            }
                        }
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        safelyShowActivityIndicator(false)
                        isLoadingSubject.send(false)
                        DDLogDebug(
                            "Mainscreen : Loading view disabled at radioFeedSuccessResponse"
                        )
                    }

                } else {
                    self.radioFeedFailureResponse(
                        message: "No radio data on local storage"
                    )
                    DDLogDebug("Mainscreen : No radio data on local storage")
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                safelyShowActivityIndicator(false)
                isLoadingSubject.send(false)
            }

            OngoingAPICallDict.shared.setObject(key: "Radio", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Radio") == true {
                DDLogDebug("Mainscreen : Process Pending Radio Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Radio",
                    value: false
                )
                self.getRadioFeed()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in radioFeedSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    func radioFeedFailureResponse(message: String, isNetworkError: Bool = false) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : radio feed failure response \(message)")
            if !isNetworkError {
                self.radioConnection.stopRadio()
                self.radioConnection.radioPlayingStatus = false
                self.isRadioPlayingSubject.send(false)
                self.radioConnection.isRadioPausedDueToAlerts = false
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    updateRadioIcon(status: false, isNetworkDown: false)
                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at radioFeedFailureResponse"
                    )
                }
            }
            OngoingAPICallDict.shared.setObject(key: "Radio", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Radio") == true {
                DDLogDebug("Mainscreen : Process Pending Radio Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Radio",
                    value: false
                )
                self.getRadioFeed()
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in radioFeedFailureResponse - \(String(describing: exception))"
            )
        }
    }

    func updateRadioIcon(status: Bool, isNetworkDown: Bool) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Radio playing status update")
            if status, !isNetworkDown {
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    DDLogDebug("Mainscreen : Radio On Icon updated")
                    radioPlayingIcon?.image = UIImage(named: "Radio_On")
                }
            } else {
                if self.radioConnection.radioPlayingStatus ?? false {
                    self.radioConnection.stopRadio()
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    if isNetworkDown {
                        DDLogDebug("Mainscreen : Radio Down Icon updated")
                        radioPlayingIcon?.image = UIImage(named: "Radio_Down")
                    } else {
                        DDLogDebug("Mainscreen : Radio Off Icon updated")
                        radioPlayingIcon?.image = UIImage(named: "Radio_Off")
                    }
                }
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in updateRadioIcon - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Event view delegates

    func getEvents() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Get Event Details")
            eventsConnection.mainViewdelegate = self
            eventsConnection.getEventsData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getEvents - \(String(describing: exception))"
            )
        }
    }

    func eventsSuccessResponse() {
        SwiftTryCatch.try {
            // Skip events processing for UI types that don't display events
            guard self.actualUIType != 2, self.actualUIType != 5, self.actualUIType != 6 else {
                DDLogDebug("Mainscreen : Skipping events processing for UIType \(self.actualUIType) (events not displayed)")
                return
            }

            DDLogDebug("Mainscreen : CustomHomePage view is disabled")
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                safelyShowActivityIndicator(true)
                isLoadingSubject.send(true)
                DDLogDebug(
                    "Mainscreen : Loading view enabled at eventsSuccessResponse"
                )
            }
            DDLogDebug("Mainscreen : Fetching Event details")
            let eventsData = DataHandler().fetchData(
                "Event",
                self.managedContext
            )
            let eventListData = DataHandler().fetchData(
                "EventList",
                self.managedContext
            )

            self.managedContext.performAndWait {
                if eventsData?.count ?? 0 > 0, eventListData?.count ?? 0 > 0 {
                    let data = eventsData?[0] as? Event

                    var tempEventListArray = [
                        (String, String, String, String, String, Bool)
                    ]()
                    self.multiCalendarStatus = data?.multiCalendar ?? false
                    DDLogDebug("Mainscreen : EventList Array initiated")
                    for i in 0 ..< (eventListData?.count ?? 0) {
                        let list = eventListData?[i] as? EventList

                        tempEventListArray.append(
                            (
                                list?.startTime ?? "",
                                list?.endTime ?? "",
                                list?.eventName ?? "",
                                list?.calendarName ?? "",
                                list?.eventDescription ?? "",
                                false
                            )
                        )

                        DDLogDebug(
                            "Mainscreen : EventList Array Data append : \(i + 1)"
                        )
                    }
                    DDLogDebug(
                        "Mainscreen : EventList Data - \(tempEventListArray)"
                    )

                    // Store the unhighlight array temporarily using thread-safe method but without UI update
                    self.setEventListArrayDirectly(tempEventListArray)

                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        isTodayActivityPresent = true
                        weatherDisplayTimer?.invalidate()
                        eventAnimationTimer?.invalidate()
                        onGoingEventScheduleTimer?.invalidate()

                        DDLogDebug(
                            "Mainscreen : Checking initially for onGoingEvents"
                        )

                        // Apply highlighting and update UI in one step
                        iterateThroughEventArray()

                        // iterateThroughEventArray() will call updateEventList() if highlighting changes are made

                        // Then check for ongoing events scheduling
                        updateOnGoingEvents()

                        safelyShowActivityIndicator(false)
                        isLoadingSubject.send(false)
                        DDLogDebug(
                            "Mainscreen : Loading view disabled at eventsSuccessResponse"
                        )

                        fourDayWeatherView?.isHidden = true
                        detailedWeatherView?.isHidden = true
                        eventListView?.isHidden = true
                        // single calendar animation count 4
                        // multiple calendar animation count 6

                        // Get events AFTER highlighting has been applied - wait for async highlighting to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            var animateCheck = false
                            let currentEvents = self.getEventListCopy()
                            if self.multiCalendarStatus {
                                if currentEvents.count > 3 {
                                    animateCheck = true
                                } else {
                                    animateCheck = false
                                }
                            } else {
                                if currentEvents.count > 4 {
                                    animateCheck = true
                                } else {
                                    animateCheck = false
                                }
                            }

                            self.eventYOffset = -10
                            self.eventDataCount = 0
                            DDLogDebug("Mainscreen : Check for event animation")
                            if animateCheck {
                                // Use events without duplication
                                self.updateEventList(currentEvents)
                                self.eventListTable?.contentOffset.y = CGFloat(
                                    self.eventYOffset
                                )
                                self.eventListTable?.reloadData()

                                // Only show eventListView if not in carousel-only mode
                                if !self.isCarouselOnlyModeActive {
                                    self.eventListView?.isHidden = false
                                }

                                self.eventAnimationTimer?.invalidate()

                                // Only start animation timer if not in carousel-only mode
                                if !self.isCarouselOnlyModeActive {
                                    self.eventAnimationTimer =
                                        Timer.scheduledTimer(
                                            timeInterval: 15,
                                            target: self,
                                            selector: #selector(
                                                self.animateTodayEvents
                                            ),
                                            userInfo: nil,
                                            repeats: true
                                        )
                                }
                            } else {
                                self.eventAnimationTimer?.invalidate()
                                self.eventListTable?.contentOffset.y = CGFloat(
                                    self.eventYOffset
                                )
                                self.eventListTable?.reloadData()

                                // Only show eventListView if not in carousel-only mode
                                if !self.isCarouselOnlyModeActive {
                                    self.eventListView?.isHidden = false
                                }
                            }
                        }
                    } // End of asyncAfter block

                } else {
                    self.eventFailureResponse(
                        message: "No Events data on local storage"
                    )
                    DDLogDebug(
                        "Mainscreen : No Events data on local storage"
                    )
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                safelyShowActivityIndicator(false)
                isLoadingSubject.send(false)
            }

            OngoingAPICallDict.shared.setObject(key: "Events", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Events") == true {
                DDLogDebug("Mainscreen : Process Pending Events Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Events",
                    value: false
                )
                self.getEvents()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in eventsSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    func eventFailureResponse(message: String, isNetworkError: Bool = false) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : event failure Response \(message)")
            if !isNetworkError {
                self.isTodayActivityPresent = false
                self.updateEventList([])
                self.scheduledEventTimings = [Date]()
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    eventListView?.isHidden = true
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at eventFailureResponse"
                    )
                    eventListTable?.reloadData()
                    eventAnimationTimer?.invalidate()
                    onGoingEventScheduleTimer?.invalidate()
                }
            }

            DDLogDebug("Mainscreen : check weather and present if any")

            self.weatherSuccessResponse()

            OngoingAPICallDict.shared.setObject(key: "Events", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "Events") == true {
                DDLogDebug("Mainscreen : Process Pending Events Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "Events",
                    value: false
                )
                self.getEvents()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in eventFailureResponse - \(String(describing: exception))"
            )
        }
    }

    @objc func animateTodayEvents() {
        SwiftTryCatch.try {
            guard !self.isPortraitModeActive else {
                DDLogDebug(
                    "MainScreen: Ignoring animateTodayEvents while in portrait mode"
                )
                self.eventAnimationTimer?.invalidate()
                return
            }
            guard !self.isCarouselOnlyModeActive else {
                DDLogDebug(
                    "MainScreen: Ignoring animateTodayEvents while in carousel-only mode (UI Types 5 & 6)"
                )
                self.eventAnimationTimer?.invalidate()
                return
            }
            guard self.actualUIType != 2, self.actualUIType != 5, self.actualUIType != 6 else {
                DDLogDebug(
                    "MainScreen: Ignoring animateTodayEvents for UIType \(self.actualUIType) (events not displayed)"
                )
                self.eventAnimationTimer?.invalidate()
                return
            }

            DDLogDebug("Mainscreen : Animate Events")
            self.eventDataCount += 1
            let currentEventsCount = self.getEventListCopy().count
            // Calculate steps needed to scroll through all events completely
            // Need enough steps to ensure every event gets shown, including the last ones
            let visibleEventsAtOnce = self.multiCalendarStatus ? 3 : 4 // Events visible in viewport
            let extraSteps = 2 // Increased buffer steps to ensure last events are fully displayed
            let maxSteps = currentEventsCount - visibleEventsAtOnce + extraSteps + 1
            if self.eventDataCount >= maxSteps {
                self.eventYOffset = -10
                self.eventDataCount = 0
            }
            if self.eventDataCount == 0 {
                // Reset scroll position smoothly without hiding the view
                self.eventListTable?.contentOffset.y = CGFloat(
                    self.eventYOffset
                )
                self.eventAnimationTimer?.invalidate()
                self.eventAnimationTimer = Timer.scheduledTimer(
                    timeInterval: 15,
                    target: self,
                    selector: #selector(self.animateTodayEvents),
                    userInfo: nil,
                    repeats: true
                )

            } else {
                DDLogDebug(
                    "Mainscreen : Animating only when the timer is active"
                )
                if self.eventAnimationTimer?.isValid == true { // Animating only when the timer is active
                    if self.multiCalendarStatus {
                        self.eventYOffset += 135
                    } else {
                        self.eventYOffset += 105
                    }
                    self.eventListView?.isHidden = false
                    UIView.animate(
                        withDuration: 15,
                        delay: 0.0,
                        options: .curveLinear,
                        animations: {
                            self.eventListTable?.contentOffset.y = CGFloat(
                                self.eventYOffset
                            )
                            self.eventListView?.layoutIfNeeded()
                        },
                        completion: nil
                    )
                }
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in animateToadyEvents - \(String(describing: exception))"
            )
        }
    }

    func updateOnGoingEvents() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : update on going events")

            // Cancel any existing scheduled updates first
            self.portraitEventUpdateWorkItem?.cancel()
            self.onGoingEventScheduleTimer?.invalidate()

            self.scheduledEventTimings = [Date]()

            // Common logic - always run this regardless of mode
            self.iterateThroughEventArray()

            // Early exit if no events need scheduling
            if self.scheduledEventTimings.isEmpty {
                DDLogDebug("Mainscreen : No upcoming event status changes")
                return
            }

            // Calculate next update time - shared logic for both modes
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "HH:mm:ss"

            guard
                let currentTime = dateFormatter.date(
                    from: dateFormatter.string(from: Date())
                ),
                let nextMinimumUpdateTime = self.scheduledEventTimings.min()
            else {
                DDLogDebug("Mainscreen : Cannot calculate next update time")
                return
            }

            let nextEventUpdateInterval = max(
                nextMinimumUpdateTime.timeIntervalSince1970
                    - currentTime.timeIntervalSince1970,
                1.0
            )

            // Mode-specific scheduling logic
            if self.isPortraitModeActive {
                DDLogDebug(
                    "Mainscreen : Portrait mode - using DispatchQueue for event updates in \(nextEventUpdateInterval) seconds"
                )

                // Cancel any existing portrait mode work item
                self.portraitEventUpdateWorkItem?.cancel()

                // Create new work item for portrait mode
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self, isPortraitModeActive else {
                        DDLogDebug(
                            "Mainscreen : Portrait mode update cancelled - no longer in portrait mode"
                        )
                        return
                    }

                    DDLogDebug(
                        "Mainscreen : Running scheduled portrait mode event update"
                    )
                    updateOnGoingEvents()
                }

                self.portraitEventUpdateWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + nextEventUpdateInterval, execute: workItem)
            } else {
                DDLogDebug(
                    "Mainscreen : Landscape mode - using Timer for event updates"
                )

                // Use Timer for landscape mode
                self.onGoingEventScheduleTimer = Timer.scheduledTimer(
                    timeInterval: nextEventUpdateInterval,
                    target: self,
                    selector: #selector(self.refreshEvent),
                    userInfo: nil,
                    repeats: false
                )
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in updateOnGoingEvents - \(String(describing: exception))"
            )
        }
    }

    func iterateThroughEventArray() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Event Array iteration")
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "HH:mm:ss"

            let currentTime = dateFormatter.date(
                from: dateFormatter.string(from: Date())
            )

            if currentTime != nil {
                var currentEvents = self.getEventListCopy()
                var hasChanges = false

                for i in 0 ..< currentEvents.count {
                    let originalHighlighting = currentEvents[i].5

                    if currentEvents[i].0 == "All Day" {
                        currentEvents[i] = (currentEvents[i].0, currentEvents[i].1, currentEvents[i].2, currentEvents[i].3, currentEvents[i].4, true)
                        if !originalHighlighting {
                            hasChanges = true
                            DDLogDebug("Mainscreen : All day event highlighting CHANGED for \(currentEvents[i].2)")
                        } else {
                            DDLogDebug("Mainscreen : All day event already highlighted \(currentEvents[i].2)")
                        }
                    } else {
                        // Convert 12-hour event times to 24-hour format strings (like carousel data)
                        let startTimeString = self.convertTo24HourFormat(currentEvents[i].0)
                        let endTimeString = self.convertTo24HourFormat(currentEvents[i].1)

                        let startTime = dateFormatter.date(from: startTimeString)
                        let endTime = dateFormatter.date(from: endTimeString)

                        if startTime != nil {
                            if endTime != nil {
                                if currentTime! >= startTime!, currentTime! < endTime! {
                                    currentEvents[i] = (currentEvents[i].0, currentEvents[i].1, currentEvents[i].2, currentEvents[i].3, currentEvents[i].4, true)
                                    if !originalHighlighting {
                                        hasChanges = true
                                        DDLogDebug("Mainscreen : On Going event highlighting CHANGED for \(currentEvents[i].2)")
                                    } else {
                                        DDLogDebug("Mainscreen : On Going event already highlighted \(currentEvents[i].2)")
                                    }
                                    self.scheduledEventTimings.append(endTime!) // collecting end time for the ongoing events
                                } else {
                                    currentEvents[i] = (currentEvents[i].0, currentEvents[i].1, currentEvents[i].2, currentEvents[i].3, currentEvents[i].4, false)
                                    if originalHighlighting {
                                        hasChanges = true
                                        DDLogDebug("Mainscreen : Event highlighting REMOVED for \(currentEvents[i].2)")
                                    } else {
                                        DDLogDebug("Mainscreen : Event already not highlighted \(currentEvents[i].2)")
                                    }
                                    if startTime! > currentTime! { // collecting start time of future events
                                        self.scheduledEventTimings.append(
                                            startTime!
                                        )
                                    }
                                }

                            } else {
                                DDLogDebug(
                                    "Mainscreen : can not convert event end date in given format"
                                )
                            }
                        } else {
                            DDLogDebug(
                                "Mainscreen : can not convert event start date in given format"
                            )
                        }
                    }
                }

                // Update the array with changes if any modifications were made
                if hasChanges {
                    DDLogDebug("Mainscreen : Event highlighting applied - updating UI with highlighted events")
                    self.updateEventList(currentEvents)
                    // Both table view reload and portrait view notification are now handled by updateEventList
                } else {
                    DDLogDebug("Mainscreen : No event highlighting changes needed - events already have correct highlighting state")
                }
            } else {
                DDLogDebug(
                    "Mainscreen : can not convert event current date in given format"
                )
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in iterateThroughEventArray - \(String(describing: exception))"
            )
        }
    }

    @objc func refreshEvent() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Refresh event called")
            self.iterateThroughEventArray()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in refreshEvent - \(String(describing: exception))"
            )
        }
    }

    // MARK: Status indicator view delegates

    func getStatusIndicator() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Get Status Indicator Details")
            statusIndicatorConnection.mainViewDelegate = self
            statusIndicatorConnection.getStatusIndicatorData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getStatusIndicator - \(String(describing: exception))"
            )
        }
    }

    func statusIndicatorSuccessResponse() {
        SwiftTryCatch.try {
            // Skip status indicator processing for UI types that don't display status indicators
            guard self.actualUIType != 4, self.actualUIType != 5, self.actualUIType != 6 else {
                DDLogDebug("Mainscreen : Skipping status indicator processing for UIType \(self.actualUIType) (status indicators not displayed)")
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                safelyShowActivityIndicator(true)
                isLoadingSubject.send(true)
                DDLogDebug(
                    "Mainscreen : Loading view enabled at statusIndicatorSuccessResponse"
                )
            }

            DDLogDebug("Mainscreen : Fetching Status Indicator data")
            self.managedContext.performAndWait {
                let statusData = DataHandler().fetchData(
                    "StatusIndicator",
                    self.managedContext
                )
                DDLogDebug("Mainscreen : Checking Status Indicator data")
                if statusData?.count ?? 0 > 0 {
                    var tempStatusIndicatorArray = [(String, String, Int)]()

                    for i in 0 ..< (statusData?.count ?? 0) {
                        let data = statusData?[i] as? StatusIndicator
                        tempStatusIndicatorArray.append(
                            (
                                data?.statusName ?? "", data?.message ?? "",
                                Int(data?.statusFlag ?? 2)
                            )
                        )
                        DDLogDebug(
                            "Mainscreen : Status Indicator Array data append : \(i + 1) - \(String(describing: data))"
                        )
                    }

                    DDLogDebug(
                        "Mainscreen : Status Indicator Array initiated - \(tempStatusIndicatorArray)"
                    )

                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        // Use the thread-safe update method
                        updateStatusIndicators(tempStatusIndicatorArray)

                        // Only show statusIndicatorSuperView if not in carousel-only mode
                        if !isCarouselOnlyModeActive {
                            statusIndicatorSuperView?.isHidden = false
                        }

                        safelyShowActivityIndicator(false)
                        isLoadingSubject.send(false)
                        DDLogDebug(
                            "Mainscreen : Loading view disabled at statusIndicatorSuccessResponse"
                        )

                        if Int(
                            ceil(CGFloat(tempStatusIndicatorArray.count) / 2.0)
                        ) > 1 {
                            statusContentTextOffset = 0.0

                            statusAnimationTimer?.invalidate()

                            // Only start status animation timer if not in carousel-only mode
                            if !isCarouselOnlyModeActive {
                                statusAnimationTimer =
                                    Timer.scheduledTimer(
                                        timeInterval: 10,
                                        target: self,
                                        selector: #selector(
                                            animateTodayStatus
                                        ),
                                        userInfo: nil,
                                        repeats: true
                                    )
                            }
                        } else {
                            statusAnimationTimer?.invalidate()

                            // Only reload status indicator collection view if not in carousel-only mode
                            if !isCarouselOnlyModeActive {
                                statusIndicatorCollectionView?.reloadData()
                                statusIndicatorCollectionView?.collectionViewLayout.invalidateLayout()
                            }
                        }
                    }

                } else {
                    self.statusIndicatorFailureResponse(
                        message: "No Status Indicator data on local storage"
                    )
                    DDLogDebug(
                        "Mainscreen : No Status indicator data on local storage"
                    )
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                safelyShowActivityIndicator(false)
                isLoadingSubject.send(false)
            }

            OngoingAPICallDict.shared.setObject(
                key: "StatusIndicator",
                value: false
            )
            if PendingAPICallRequestDict.shared.getValue(key: "StatusIndicator")
                == true
            {
                DDLogDebug(
                    "Mainscreen : Process Pending StatusIndicator Request"
                )
                PendingAPICallRequestDict.shared.setObject(
                    key: "StatusIndicator",
                    value: false
                )
                self.getStatusIndicator()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in statusIndicatorSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    @objc func animateTodayStatus() {
        SwiftTryCatch.try {
            guard !self.isPortraitModeActive else {
                DDLogDebug(
                    "MainScreen: Ignoring animateTodayStatus while in portrait mode"
                )
                self.statusAnimationTimer?.invalidate()
                return
            }
            guard !self.isCarouselOnlyModeActive else {
                DDLogDebug(
                    "MainScreen: Ignoring animateTodayStatus while in carousel-only mode (UI Types 5 & 6)"
                )
                self.statusAnimationTimer?.invalidate()
                return
            }

            // Prevent overlapping animations
            guard !self.isStatusAnimating else {
                DDLogDebug("MainScreen: Status indicator animation already in progress, skipping")
                return
            }

            DDLogDebug("Mainscreen : Animate Status Indicators")
            self.isStatusAnimating = true

            // Simple pagination logic
            let collectionViewWidth = self.statusIndicatorCollectionView?.bounds.size.width ?? 0
            let totalItems = self.getStatusIndicatorsCopy().count
            let itemsPerPage = 2
            let totalPages = max(1, Int(ceil(Double(totalItems) / Double(itemsPerPage))))

            // Calculate current page from current offset
            let currentPage = Int(round((self.statusIndicatorCollectionView?.contentOffset.x ?? 0) / collectionViewWidth))
            let nextPage = (currentPage + 1) % totalPages

            // Set target offset to next page
            self.statusContentTextOffset = CGFloat(nextPage) * collectionViewWidth

            UIView.animate(
                withDuration: 1,
                delay: 0.0,
                options: .curveLinear,
                animations: {
                    self.statusIndicatorCollectionView?.contentOffset.x = self.statusContentTextOffset
                },
                completion: { _ in
                    self.isStatusAnimating = false
                }
            )

            // Update page control based on current page
            let currentPageIndex = Int(round((self.statusIndicatorCollectionView?.contentOffset.x ?? 0) / collectionViewWidth))

            // Ensure page control has correct number of pages
            let totalStatusItems = self.getStatusIndicatorsCopy().count
            let expectedPages = totalStatusItems <= 0 ? 0 : Int(ceil(CGFloat(totalStatusItems) / 2.0))
            if self.StatusIndicatorPageControl.numberOfPages != expectedPages {
                self.adjustStatusIndicatorPageControl(
                    withCurrentPage: currentPageIndex,
                    andNumberOfPage: max(1, expectedPages)
                )
            } else {
                self.StatusIndicatorPageControl.currentPage = currentPageIndex
            }

            self.StatusIndicatorPageControl.customPageControl(
                dotFillColor: UIColor(named: "StatusSelectedPagingEnd")!,
                dotBorderColor: UIColor(named: "StatusPagingColor")!,
                dotBorderWidth: 1.0,
                dotRadius: 5
            )
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in animateToadyStatus - \(String(describing: exception))"
            )
        }
    }

    func statusIndicatorFailureResponse(
        message: String,
        isNetworkError: Bool = false
    ) {
        SwiftTryCatch.try {
            DDLogDebug(
                "Mainscreen : status indicator failure response \(message)"
            )
            if !isNetworkError {
                // Use the thread-safe update method to clear the array
                self.updateStatusIndicators([])
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    statusIndicatorSuperView?.isHidden = true
                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at statusIndicatorFailureResponse"
                    )

                    statusAnimationTimer?.invalidate()
                    statusIndicatorCollectionView?.reloadData()
                }
            }
            // handle when no status indicator available to present. (back to static icons)

            OngoingAPICallDict.shared.setObject(
                key: "StatusIndicator",
                value: false
            )
            if PendingAPICallRequestDict.shared.getValue(key: "StatusIndicator")
                == true
            {
                DDLogDebug(
                    "Mainscreen : Process Pending StatusIndicator Request"
                )
                PendingAPICallRequestDict.shared.setObject(
                    key: "StatusIndicator",
                    value: false
                )
                self.getStatusIndicator()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in statusIndicatorFailureResponse - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Scrolling Message delegates

    func getScrollingMessageFeed() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Get Scrolling Message Feed")
            scrollingMsgConnection.mainViewdelegate = self
            scrollingMsgConnection.getScrollMessageData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getScrollingMessageFeed - \(String(describing: exception))"
            )
        }
    }

    func scrollingMsgSuccessResponse() {
        SwiftTryCatch.try {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                safelyShowActivityIndicator(true)
                isLoadingSubject.send(true)
                DDLogDebug(
                    "Mainscreen : Loading view enabled at scrolling scrollingMsgSuccessResponse"
                )
            }

            DDLogDebug("Mainscreen : Fetch Scrolling Message Details")
            DDLogDebug("Mainscreen : Scrollable Text initiated")
            self.scrollableText = ""
            self.managedContext.performAndWait {
                let scrollingMsgData = DataHandler().fetchData(
                    "ScrollMessage",
                    self.managedContext
                )
                DDLogDebug("Mainscreen : Check Scrolling Message data")
                if scrollingMsgData?.count ?? 0 > 0 {
                    for i in 0 ..< (scrollingMsgData?.count ?? 0) {
                        let data = scrollingMsgData?[i] as? ScrollMessage
                        let temString = data?.messageDescription ?? ""
                        self.scrollableText = self.scrollableText + temString
                        DDLogDebug(
                            "Mainscreen : Scrollable Text data append : \(i + 1)"
                        )
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        safelyShowActivityIndicator(false)
                        isLoadingSubject.send(false)
                        setScrollableView()
                    }

                } else {
                    DDLogDebug(
                        "Mainscreen : No scrolling message found in data base"
                    )
                    self.scrollingMsgFailureResponse(
                        message: "No Scrolling found in data base"
                    )
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                safelyShowActivityIndicator(false)
                isLoadingSubject.send(false)
            }

            OngoingAPICallDict.shared.setObject(
                key: "ScrollMessage",
                value: false
            )
            if PendingAPICallRequestDict.shared.getValue(key: "ScrollMessage")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending ScrollMessage Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "ScrollMessage",
                    value: false
                )
                self.getScrollingMessageFeed()
            }

        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in scrollingMsgSuccessResponse - \(String(describing: exception))"
            )
        }
    }

    func scrollingMsgFailureResponse(
        message: String,
        isNetworkError: Bool = false
    ) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : scroll text failure response \(message)")
            if !isNetworkError {
                DDLogDebug("Mainscreen : Disable Scrollable Text Label")
                self.scrollableText = ""
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    scrollableTextView?.contentOffset.x =
                        0
                    scrollableTextView?.isHidden = true

                    if scrollableTextLabel != nil {
                        scrollableTextLabel?.removeFromSuperview()
                        scrollableTextLabel = nil
                    }

                    scrollbarTimer?.invalidate()
                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at scrollingMsgFailureResponse"
                    )
                }
            }

            OngoingAPICallDict.shared.setObject(
                key: "ScrollMessage",
                value: false
            )
            if PendingAPICallRequestDict.shared.getValue(key: "ScrollMessage")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending ScrollMessage Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "ScrollMessage",
                    value: false
                )
                self.getScrollingMessageFeed()
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in scrollingMsgFailureResponse - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Sara Alert Message delegates

    @objc func refreshSaraAlertModel() {
        DDLogDebug("Mainscreen : Refresh Sara Alert Model")
        viewUpdateHandlerConnection.mainViewdelegate = self
        viewUpdateHandlerConnection.managedObjectContext = managedContext
        viewUpdateHandlerConnection.refreshSaraAlertModel()
    }

    func getSaraAlertFeed() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Get SARA Alert Feed")
            saraAlertConnection.mainViewdelegate = self
            saraAlertConnection.getSaraAlertData()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in getSaraAlertFeed - \(String(describing: exception))"
            )
        }
    }

    func saraAlertSuccessResponse(
        _ saraAlertData: [SaraAlert],
        _ saraAlertHeader: [SaraHeader],
        _ saraAlertFooter: [SaraFooter],
        _ saraAlertBody: [SaraBody],
        _ saraAlertBodyText: [SaraBodyText],
        _ saraAlertBodyIndividual: [SaraBodyIndividual]
    ) {
        DispatchQueue.main.async {
            self.safelyShowActivityIndicator(true)
            self.isLoadingSubject.send(true)
            DDLogDebug(
                "Mainscreen : Loading view enabled at sara alert success Response scrollingMsgSuccessResponse"
            )
        }

        DDLogDebug("Mainscreen : Fetching SARA Alert Data")

        DDLogDebug(
            "Mainscreen : Checking that data base has some non-empty alerts to present"
        )

        managedContext.performAndWait {
            if !saraAlertData.isEmpty,
               (!saraAlertHeader.isEmpty) || (!saraAlertFooter.isEmpty)
               || (!saraAlertBody.isEmpty) || (!saraAlertBodyText.isEmpty)
               || (!saraAlertBodyIndividual.isEmpty)
            {
                // Set SARA alert flag immediately when valid data exists
                self.isSaraAlertPresented = true
                self.saraAlertTriggered = 1

                // Save clock state before disabling it
                if self.isClockPresented {
                    DDLogDebug(
                        "Mainscreen: Saving clock state before SARA alert"
                    )
                    self.showClockTriggered = 1
                } else {
                    self.showClockTriggered = 0
                }

                DDLogDebug("Mainscreen : Stop the radio if sara alert comes in")
                // Stop the radio if sara alert comes in.

                self.radioConnection.isRadioPausedDueToAlerts = true
                self.radioConnection.radioPlayingStatus = false
                self.isRadioPlayingSubject.send(false)
                self.radioConnection.stopRadio()
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    radioPlayingIcon?.image = UIImage(
                        named: "Radio_Off"
                    )
                }
                DDLogDebug("Mainscreen : Radio off,due to SARA Alert")

                self.disableClock()

                // Stop any ongoing carousel narration
                if self.isNarrationPlaying {
                    self.narrationAudioPlayer.stopCurrentAudio()
                    self.isNarrationPlaying = false
                    DDLogDebug(
                        "Mainscreen : Carousel narration paused due to SARA Alert"
                    )
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    DDLogDebug("Mainscreen : Presenting SARA Alert")
                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)

                    carousalView?.isHidden = true
                    carousalImageTimer?.invalidate()
                    presentDefaultSlide()

                    saraAlertView?.isHidden = false
                    setSaraAlertLayout(
                        saraAlertData: saraAlertData,
                        saraAlertHeader: saraAlertHeader,
                        saraAlertFooter: saraAlertFooter,
                        saraAlertBody: saraAlertBody,
                        saraAlertBodyText: saraAlertBodyText,
                        saraAlertBodyIndividual: saraAlertBodyIndividual
                    )
                }
            } else {
                self.saraAlertFailureResponse(
                    message: "No Sara alert data found in data base"
                )
                DDLogDebug(
                    "Mainscreen : No sara alert message found in data base"
                )
            }
        }

        DispatchQueue.main.async {
            self.safelyShowActivityIndicator(false)
            self.isLoadingSubject.send(false)
        }

        OngoingAPICallDict.shared.setObject(key: "SaraAlert", value: false)
        if PendingAPICallRequestDict.shared.getValue(key: "SaraAlert") == true {
            DDLogDebug("Mainscreen : Process Pending SaraAlert Request")
            PendingAPICallRequestDict.shared.setObject(
                key: "SaraAlert",
                value: false
            )
            getSaraAlertFeed()
        }
    }

    func saraAlertFailureResponse(
        message _: String,
        isNetworkError: Bool = false
    ) {
        SwiftTryCatch.try {
            if !isNetworkError {
                self.saraAlertTriggered = 0

                if self.showClockTriggered == 1 {
                    self.enableClock()
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    saraAlertFlashTimer?.invalidate()
                    if saraAlertAudioPlayer != nil {
                        saraAlertAudioPlayer?.stop()
                        saraAlertAudioPlayer = nil
                    }
                    saraAlertFlashFlag = false

                    saraAlertView?.isHidden = true

                    carousalView?.isHidden = false
                    if !carousalImageArray.isEmpty {
                        // Restarting carousel image
                        // This is to prevent a scenario where the TV restarts with emergency alert
                        // when alert is cleared the carousel timer is not restarted and
                        // the TV shows the default carousel side
                        carousalImageTimer?.invalidate()

                        DDLogDebug(
                            "Mainscreen : Carousal Timer Restart,Due to no SARA Response"
                        )
                        changeCarousalImage()
                    }

                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    DDLogDebug(
                        "Mainscreen : Loading view disabled at saraAlertFailureResponse"
                    )
                }

                self.isSaraAlertPresented = false

                if self.showClockTriggered == 1 {
                    self.enableClock()
                }

                // Radio paused last time due to alerts
                if self.radioConnection.isRadioPausedDueToAlerts {
                    self.radioConnection.isRadioPausedDueToAlerts = false
                }

                // Resume any paused carousel narration
                if self.narrationAudioPlayer.audioPlayer != nil,
                   self.narrationAudioPlayer.audioPlayer?.isPlaying == false
                {
                    self.narrationAudioPlayer.audioPlayer?.play()
                    self.isNarrationPlaying = true
                    DDLogDebug(
                        "Mainscreen : Carousel narration resumed after SARA Alert"
                    )
                }

                if DataFetchingUtility.shouldFetchData(for: .radio, uiType: self.actualUIType, radioFlag: self.tvRadioFlag, context: "MainScreen") {
                    self.getRadioFeed()
                }
            }
            OngoingAPICallDict.shared.setObject(key: "SaraAlert", value: false)
            if PendingAPICallRequestDict.shared.getValue(key: "SaraAlert")
                == true
            {
                DDLogDebug("Mainscreen : Process Pending SaraAlert Request")
                PendingAPICallRequestDict.shared.setObject(
                    key: "SaraAlert",
                    value: false
                )
                self.getSaraAlertFeed()
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in saraAlertFailureResponse - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Network down delegates

    @objc func networkStatusChanged(notification _: NSNotification) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Network reachability changed on Home page")

            let currentNetworkState = isNetworkReachable

            // Only process if network state actually changed
            if self.lastNetworkState != currentNetworkState
                || self.isFirstNetworkNotification
            {
                DDLogDebug(
                    "Mainscreen: Network state actually changed from \(self.lastNetworkState) to \(currentNetworkState)"
                )
                self.lastNetworkState = currentNetworkState

                self.isFirstNetworkNotification = false

                if currentNetworkState {
                    DDLogDebug("Mainscreen : Network Status - Reachable")
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        safelyShowActivityIndicator(false)
                        isLoadingSubject.send(false)
                        networkDownIndication?.isHidden = true
                        isNetworkDownSubject.send(false)
                    }

                    self.radioFeedSuccessResponse()
                    socketConnection.mainViewdelegate = self

                    if domainAddress != nil, roomNo != nil {
                        socketConnection.startSocketConnection(
                            withAddress: domainAddress!,
                            roomNumber: roomNo!
                        )
                    }

                    // Restart carousel when network reconnects
                    if !self.carousalImageArray.isEmpty,
                       !self.isSaraAlertPresented,
                       !self.isNarrationPausedDueToClock
                    {
                        DDLogDebug(
                            "Mainscreen: Network reconnected - forcing carousel refresh"
                        )
                        self.carousalImageTimer?.invalidate()
                        self.radioConnection.isRadioPausedDueToNarration = false
                        self.changeCarousalImage()
                    }
                } else {
                    DDLogDebug("Mainscreen : Network status - Not Reachable")
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        safelyShowActivityIndicator(false)
                        isLoadingSubject.send(false)
                        networkDownIndication?.isHidden = false
                        isNetworkDownSubject.send(true)
                    }

                    DDLogDebug(
                        "Mainscreen: Network became unavailable - cleaning up audio resources"
                    )
                    // When network goes down, properly cleanup resources
                    if self.isNarrationPlaying {
                        self.narrationAudioPlayer.cancelCurrentDownload()
                        self.narrationAudioPlayer.stopCurrentAudio()
                        self.isNarrationPlaying = false
                    }

                    if self.radioConnection.radioPlayingStatus ?? false {
                        self.radioConnection.stopRadio()
                        self.isRadioPlayingSubject.send(false)
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            return
                        }

                        updateRadioIcon(status: false, isNetworkDown: true)
                    }

                    socketConnection.closeSocketConnection()

                    // Handle carousel during network outage
                    if !self.carousalImageArray.isEmpty,
                       !self.isSaraAlertPresented,
                       !self.isNarrationPausedDueToClock
                    {
                        self.carousalImageTimer?.invalidate()
                        DDLogDebug(
                            "Mainscreen: Network disconnected - stopping carousel timer"
                        )
                        DDLogDebug(
                            "Mainscreen: Network disconnected - forcing carousel refresh"
                        )

                        self.changeCarousalImage()
                    }
                }
            } else {
                DDLogDebug(
                    "Mainscreen: Ignoring duplicate network state notification"
                )
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in networkStatusChanged - \(String(describing: exception))"
            )
        }
    }

    @objc func serverStatusChanged(notification _: NSNotification) {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Server rechability changed on home page")

            if isSocketConnectionReachable {
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    DDLogDebug("Mainscreen : NetworkDown label disabled")
                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    networkDownIndication?.isHidden = true
                    isNetworkDownSubject.send(false)
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    DDLogDebug("Mainscreen : NetworkDown label enabled")
                    safelyShowActivityIndicator(false)
                    isLoadingSubject.send(false)
                    networkDownIndication?.isHidden = false
                    isNetworkDownSubject.send(true)
                }
            }
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in serverStatusChanged - \(String(describing: exception))"
            )
        }
    }

    // MARK: - Log handling controls

    @objc func sendLogsToServer() {
        SwiftTryCatch.try {
            DDLogDebug("Mainscreen : Send Logs to Server")
            logHandlingConnection.pushLogsToServerusingJson()
        } catch: { exception in
            DDLogDebug(
                "Mainscreen : Exception in sendLogsToServer - \(String(describing: exception))"
            )
        }
    }

    /// Add a method to safely handle activity indicator operations
    func safelyShowActivityIndicator(_ show: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, isViewLoaded, view.window != nil else {
                // View is not in window hierarchy yet, skip UI updates
                return
            }

            if let loadingIndicator {
                if show {
                    // Only start if not already animating
                    if !loadingIndicator.isAnimating {
                        loadingIndicator.startAnimating()
                    }
                } else {
                    loadingIndicator.stopAnimating()
                }
            }
            DDLogDebug(
                "Mainscreen : Loading indicator \(show ? "shown" : "hidden")"
            )
        }
    }

    // MARK: - SARA Alert Layout Management

    func setupSaraAlertFullWidthLayout() {
        guard let saraAlert = saraAlertView, let centerView = centerContentView else {
            DDLogDebug("Mainscreen : Cannot setup SARA Alert full width - views not available")
            return
        }

        // Store original constraints if not already stored
        if saraAlertOriginalConstraints.isEmpty {
            // Find constraints related to SARA Alert
            saraAlertOriginalConstraints = centerView.constraints.filter { constraint in
                constraint.firstItem === saraAlert || constraint.secondItem === saraAlert
            }
            DDLogDebug(
                "Mainscreen : Stored \(saraAlertOriginalConstraints.count) original SARA Alert constraints"
            )
        }

        // Create full width constraints matching carousel layout
        let fullWidthConstraints = [
            saraAlert.leadingAnchor.constraint(
                equalTo: centerView.leadingAnchor,
                constant: 15
            ),
            saraAlert.trailingAnchor.constraint(
                equalTo: centerView.trailingAnchor,
                constant: -15
            ),
            saraAlert.topAnchor.constraint(equalTo: centerView.topAnchor),
            saraAlert.bottomAnchor.constraint(equalTo: centerView.bottomAnchor),
        ]

        saraAlertFullWidthConstraints = fullWidthConstraints
        DDLogDebug(
            "Mainscreen : Created \(saraAlertFullWidthConstraints.count) SARA Alert full width constraints"
        )
    }

    // MARK: Private

    /// Static shared cache property at class level
    private static var cachedIconImage: UIImage?

    private var isStatusAnimating = false

    private var hasCompletedInitialUISetup = false // Track if initial UI setup has been completed

    /// Private queue for thread-safe access to isNarrationPausedDueToClock
    private let narrationClockQueue = DispatchQueue(
        label: "com.statussolutions.catietv.narrationClock",
        attributes: .concurrent
    )
    private var _isNarrationPausedDueToClock = false

    /// Private queue for thread-safe access to isSaraAlertPresented
    private let saraAlertQueue = DispatchQueue(
        label: "com.statussolutions.catietv.saraAlert",
        attributes: .concurrent
    )
    private var _isSaraAlertPresented = false

    /// Private queue for thread-safe access to isNarrationPlaying
    private let narrationPlayingQueue = DispatchQueue(
        label: "com.statussolutions.catietv.narrationPlaying",
        attributes: .concurrent
    )
    private var _isNarrationPlaying = false

    // Add these properties at the class level
    private let imageCache = NSCache<NSString, UIImage>()
    private var audioIconView: UIVisualEffectView?
    private var isPreloadingNextSlide = false

    /// Private queue for thread-safe access to isPortraitModeActive
    private let portraitModeQueue = DispatchQueue(
        label: "com.statussolutions.catietv.portraitMode",
        attributes: .concurrent
    )
    private var _isPortraitModeActive: Bool = false

    /// Private queue for thread-safe access to isCarouselOnlyModeActive
    private let carouselOnlyModeQueue = DispatchQueue(
        label: "com.statussolutions.catietv.carouselOnlyMode",
        attributes: .concurrent
    )
    private var _isCarouselOnlyModeActive: Bool = false

    // Constraint storage for carousel layout management
    private var carouselFullWidthConstraints: [NSLayoutConstraint] = []
    private var carouselShadowFullWidthConstraints: [NSLayoutConstraint] = []
    private var saraAlertOriginalConstraints: [NSLayoutConstraint] = []
    private var saraAlertFullWidthConstraints: [NSLayoutConstraint] = []

    // Programmatic constraint storage for reliable UI Type switching
    private var carouselUIType1Constraints: [NSLayoutConstraint] = []
    private var carouselShadowUIType1Constraints: [NSLayoutConstraint] = []
    private var hasStoredOriginalConstraints = false

    private var isPortraitModeActive: Bool {
        get {
            portraitModeQueue.sync {
                _isPortraitModeActive
            }
        }
        set {
            portraitModeQueue.async(flags: .barrier) { [weak self] in
                self?._isPortraitModeActive = newValue
            }
        }
    }

    private func stopAllTimers() {
        eventAnimationTimer?.invalidate()
        weatherDisplayTimer?.invalidate()
        onGoingEventScheduleTimer?.invalidate()
        statusAnimationTimer?.invalidate()
        scrollbarTimer?.invalidate()
        saraAlertFlashTimer?.invalidate()
        // Reset animation states
        eventYOffset = -10
        eventDataCount = 0
        statusContentTextOffset = 0.0
        scrollTextOffset = 0
        saraAlertFlashFlag = false
    }

    private func resetStatusIndicatorScrollPosition() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            // Reset the scroll offset variable
            statusContentTextOffset = 0.0

            // Reset the collection view scroll position to the beginning
            statusIndicatorCollectionView?.contentOffset.x = 0

            // Force layout update to ensure the reset takes effect
            statusIndicatorCollectionView?.layoutIfNeeded()
        }
    }

    // MARK: - UI Type Presentation

    private func presentUIType1() {
        // Store the actual previous UI type before actualUIType gets updated
        let previousUIType = actualUIType
        DDLogDebug("Mainscreen: Presenting UI Type 1 - switching from UI Type \(previousUIType)")
        dismissPortrait()
        isCarouselOnlyModeActive = false

        // Reset status indicator scroll position
        resetStatusIndicatorScrollPosition()

        DDLogDebug("Mainscreen: About to call restoreNormalUI(for: 1) from presentUIType1")
        restoreNormalUI(for: 1)
        customDesign = 0
        customHomePageFailureResponse(message: "Mainscreen : Disable Custom Home Page")
    }

    private func presentUIType2() {
        dismissPortrait()
        isCarouselOnlyModeActive = false

        // Reset status indicator scroll position
        resetStatusIndicatorScrollPosition()

        restoreNormalUI(for: 2)

        weatherDisplayTimer?.invalidate()
        eventAnimationTimer?.invalidate()
        onGoingEventScheduleTimer?.invalidate()

        // Update custom design properties
        customDesign = 1
        customHomePageNewUI()

        // Ensure carousel layout is properly restored after customHomePageNewUI
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            // UI Type 2 should use the same carousel layout as UI Type 1 (non-full-width)
            restoreCarouselToUIType(1)
        }
    }

    private func presentUIType3() {
        DDLogDebug("Mainscreen: Presenting UI Type 3")
        customDesign = 0
        presentPortraitView()
        portraitViewController?.setUIType(3)
    }

    private func presentUIType4() {
        DDLogDebug("Mainscreen: Presenting UI Type 4")
        customDesign = 0
        presentPortraitView()
        portraitViewController?.setUIType(4)
    }

    private func presentUIType5(radioFlag: Int) {
        DDLogDebug("Mainscreen: Presenting UI Type 5 - switching from UI Type \(actualUIType) - Radio: \(radioFlag == 1 ? "Show" : "Hide")")
        dismissPortrait()
        customDesign = 0
        if radioFlag == 1 {
            carouselOnlyUI(showRadio: true) // Show radio
        } else {
            carouselOnlyUI(showRadio: false) // Hide radio
        }
    }

    private func presentUIType6(radioFlag: Int) {
        DDLogDebug("Mainscreen: Presenting UI Type 6 - Radio: \(radioFlag == 1 ? "Show" : "Hide")")
        customDesign = 0
        presentPortraitView()
        // Pass UI type 6 and let portrait view handle radio flag internally
        portraitViewController?.setUIType(6)
        portraitViewController?.setRadioFlag(radioFlag)
    }

    private func handleUITypeSwitch(targetType: Int, radioFlag: Int) {
        DDLogDebug("Mainscreen: handleUITypeSwitch called - switching to UI type \(targetType) from \(actualUIType)")
        // Update existing PortraitViewController if present
        if let pvc = portraitViewController {
            pvc.setUIType(Int16(targetType))
            // Ensure scroll text is updated when switching UI types in portrait mode
            DDLogDebug(
                "MainScreen: Resending scroll text for UI type switch: '\(scrollableText)'"
            )
            scrollableTextSubject.send(scrollableText)
        }

        // Handle radio playback based on tvRadioFlag
        handleRadioPlaybackControl()

        // Conditionally refresh modules and manage timers based on UI type
        conditionallyRefreshModulesAndManageTimers(for: targetType, radioFlag: radioFlag)

        // Handle view type switching
        DDLogDebug("Mainscreen: About to switch to target UI type: \(targetType)")
        switch targetType {
        case 1:
            DDLogDebug("Mainscreen: Calling presentUIType1()")
            presentUIType1()

        case 2:
            presentUIType2()

        case 3:
            presentUIType3()

        case 4:
            presentUIType4()

        case 5:
            presentUIType5(radioFlag: radioFlag)

        case 6:
            presentUIType6(radioFlag: radioFlag)

        default:
            dismissPortrait()
            customHomePageFailureResponse(message: "Mainscreen : Disable Custom Home Page")
        }

        // Mark initial UI setup as completed
        hasCompletedInitialUISetup = true
        DDLogDebug("Mainscreen: Marked initial UI setup as completed")
    }

    // MARK: - Radio Playback Control

    /// Handles radio playback based on tvRadioFlag
    private func handleRadioPlaybackControl() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            if tvRadioFlag == 0 {
                // Radio is disabled - stop playback if currently playing
                DDLogDebug("MainScreen: Radio disabled by tvRadioFlag - stopping playback")
                radioConnection.stopRadio()
                isRadioPlayingSubject.send(false)

                // Update radio icon to show stopped state
                updateRadioIcon(status: false, isNetworkDown: false)
            } else {
                // Radio is enabled - allow normal radio functionality
                DDLogDebug("MainScreen: Radio enabled by tvRadioFlag")
                // Note: We don't auto-start radio here, just allow it to be controlled normally
            }
        }
    }

    // MARK: - Conditional Module Refresh and Timer Management

    /// Conditionally refreshes modules and manages timers based on UI type
    /// - Parameters:
    ///   - uiType: The target UI type
    ///   - radioFlag: The radio flag (1 = show, 0 = hide)
    private func conditionallyRefreshModulesAndManageTimers(for uiType: Int, radioFlag: Int) {
        DDLogDebug("MainScreen: Conditionally refreshing modules for UI type \(uiType)")

        // Stop timers for components that won't be displayed
        stopTimersForHiddenComponents(uiType: uiType, radioFlag: radioFlag)

        // Refresh only the modules that will be displayed
        refreshModulesForUIType(uiType: uiType, radioFlag: radioFlag)

        // Restart timers for components that will be displayed
        restartTimersForDisplayedComponents(uiType: uiType, radioFlag: radioFlag)
    }

    /// Stops timers for components that won't be displayed in the target UI type
    private func stopTimersForHiddenComponents(uiType: Int, radioFlag: Int) {
        // Stop events-related timers if events won't be displayed
        if !DataFetchingUtility.shouldFetchData(for: .events, uiType: uiType, context: "MainScreen") {
            DDLogDebug("MainScreen: Stopping events timers for UI type \(uiType)")
            eventAnimationTimer?.invalidate()
            DDLogDebug("MainScreen: Invalidated eventAnimationTimer")
            onGoingEventScheduleTimer?.invalidate()
            DDLogDebug("MainScreen: Invalidated onGoingEventScheduleTimer")
            // Cancel portrait event update work item
            portraitEventUpdateWorkItem?.cancel()
            portraitEventUpdateWorkItem = nil
        }

        // Stop status indicator timers if status indicators won't be displayed
        if !DataFetchingUtility.shouldFetchData(for: .statusIndicators, uiType: uiType, context: "MainScreen") {
            DDLogDebug("MainScreen: Stopping status indicator timers for UI type \(uiType)")
            statusAnimationTimer?.invalidate()
            DDLogDebug("MainScreen: Invalidated statusAnimationTimer")
        }

        // Stop radio-related processing if radio won't be displayed
        if !DataFetchingUtility.shouldFetchData(for: .radio, uiType: uiType, radioFlag: radioFlag, context: "MainScreen") {
            DDLogDebug("MainScreen: Stopping radio for UI type \(uiType) with radioFlag \(radioFlag)")
            radioConnection.stopRadio()
            isRadioPlayingSubject.send(false)
        }

        // Stop weather display timer for all UI types except type 1 (only UI type 1 shows detailed weather views)
        if uiType != 1 {
            DDLogDebug("MainScreen: Stopping weather display timer for UI type \(uiType) (only type 1 shows detailed weather)")
            weatherDisplayTimer?.invalidate()
            DDLogDebug("MainScreen: Invalidated weatherDisplayTimer")
        }

        // Stop scrollbar timer for portrait layouts (3, 4, 6)
        if !isLandscapeLayout(uiType: uiType) {
            DDLogDebug("MainScreen: Stopping scrollbar timer for portrait UI type \(uiType)")
            scrollbarTimer?.invalidate()
            DDLogDebug("MainScreen: Invalidated scrollbarTimer")
        }
    }

    /// Refreshes only the modules that will be displayed in the target UI type
    private func refreshModulesForUIType(uiType: Int, radioFlag: Int) {
        DDLogDebug("MainScreen: Refreshing modules for UI type \(uiType)")

        // Always refresh carousel and weather (needed for all UI types)
        carousalImagesSuccessResponse()
        weatherSuccessResponse()

        // Conditionally refresh events
        if DataFetchingUtility.shouldFetchData(for: .events, uiType: uiType, context: "MainScreen") {
            DDLogDebug("MainScreen: Refreshing events for UI type \(uiType)")
            eventsSuccessResponse()
        } else {
            DDLogDebug("MainScreen: Skipping events refresh for UI type \(uiType)")
            // Clear events data and hide view
            updateEventList([])
            eventListView?.isHidden = true
        }

        // Conditionally refresh status indicators
        if DataFetchingUtility.shouldFetchData(for: .statusIndicators, uiType: uiType, context: "MainScreen") {
            DDLogDebug("MainScreen: Refreshing status indicators for UI type \(uiType)")
            statusIndicatorSuccessResponse()
        } else {
            DDLogDebug("MainScreen: Skipping status indicators refresh for UI type \(uiType)")
            // Clear status indicators data and hide view
            statusIndicatorArray = [(String, String, Int)]()
            statusIndicatorSuperView?.isHidden = true
        }

        // Conditionally refresh radio
        if DataFetchingUtility.shouldFetchData(for: .radio, uiType: uiType, radioFlag: radioFlag, context: "MainScreen") {
            DDLogDebug("MainScreen: Refreshing radio for UI type \(uiType) with radioFlag \(radioFlag)")
            radioFeedSuccessResponse()
        } else {
            DDLogDebug("MainScreen: Skipping radio refresh for UI type \(uiType) with radioFlag \(radioFlag)")
        }

        // Always refresh other essential modules
        scrollingMsgSuccessResponse()
        siteLogoSuccessResponse()

        // Refresh SARA alerts (may be needed for any UI type)
        let viewUpdateHandler = ViewUpdateHandler()
        viewUpdateHandler.mainViewdelegate = self
        viewUpdateHandler.managedObjectContext = managedContext
        viewUpdateHandler.refreshSaraAlertModel()
    }

    /// Restarts timers for components that will be displayed in the target UI type
    private func restartTimersForDisplayedComponents(uiType: Int, radioFlag _: Int) {
        DDLogDebug("MainScreen: Restarting timers for displayed components in UI type \(uiType)")

        // Restart events-related timers if events will be displayed
        if DataFetchingUtility.shouldFetchData(for: .events, uiType: uiType, context: "MainScreen") {
            DDLogDebug("MainScreen: Restarting events timers for UI type \(uiType)")

            // Restart event animation timer only for landscape UI type 1 (per CLAUDE.md specs)
            if uiType == 1, !eventListArray.isEmpty {
                restartEventAnimationTimer()
                DDLogDebug("MainScreen: Restarted event animation timer for landscape UI type 1")
            } else if uiType == 3 {
                DDLogDebug("MainScreen: Skipping event animation timer for portrait UI type 3 (uses own logic)")
            }

            // Restart ongoing event schedule timer for UI types 1, 3
            if !scheduledEventTimings.isEmpty {
                restartOnGoingEventScheduleTimer()
                DDLogDebug("MainScreen: Restarted ongoing event schedule timer for UI type \(uiType)")
            }
        }

        // Restart status indicator timers if status indicators will be displayed
        if DataFetchingUtility.shouldFetchData(for: .statusIndicators, uiType: uiType, context: "MainScreen") {
            DDLogDebug("MainScreen: Restarting status indicator timers for UI type \(uiType)")

            // Restart status animation timer only for landscape layouts (types 1, 2)
            // Portrait type 3 uses its own status indicator logic
            if isLandscapeLayout(uiType: uiType), !statusIndicatorArray.isEmpty {
                restartStatusAnimationTimer()
                DDLogDebug("MainScreen: Restarted status animation timer for landscape UI type \(uiType)")
            } else if !isLandscapeLayout(uiType: uiType) {
                DDLogDebug("MainScreen: Skipping status animation timer for portrait UI type \(uiType) (uses own logic)")
            }
        }

        // Restart weather display timer only for UI type 1 (only type 1 shows detailed weather views)
        if uiType == 1 {
            DDLogDebug("MainScreen: Restarting weather display timer for UI type 1 (detailed weather cycling)")
            restartWeatherDisplayTimer()
        }

        // Conditionally restart scrollbar timer (only for landscape layouts)
        if isLandscapeLayout(uiType: uiType) {
            DDLogDebug("MainScreen: Restarting scrollbar timer for landscape UI type \(uiType)")
            restartScrollbarTimer()
        } else {
            DDLogDebug("MainScreen: Skipping scrollbar timer for portrait UI type \(uiType)")
        }

        // Always restart carousel timer
        restartCarouselTimer()
    }

    // MARK: - Timer Restart Methods

    /// Restarts the event animation timer
    private func restartEventAnimationTimer() {
        eventAnimationTimer?.invalidate()

        // Start event animation timer using existing method
        eventAnimationTimer = Timer.scheduledTimer(
            timeInterval: 15,
            target: self,
            selector: #selector(animateTodayEvents),
            userInfo: nil,
            repeats: true
        )
        DDLogDebug("MainScreen: Restarted eventAnimationTimer")
    }

    /// Restarts the ongoing event schedule timer
    private func restartOnGoingEventScheduleTimer() {
        onGoingEventScheduleTimer?.invalidate()

        // Calculate next event timing and start timer using existing method
        if let nextEventTime = scheduledEventTimings.first(where: { $0 > Date() }) {
            let timeInterval = nextEventTime.timeIntervalSinceNow
            onGoingEventScheduleTimer = Timer.scheduledTimer(
                timeInterval: timeInterval,
                target: self,
                selector: #selector(refreshEvent),
                userInfo: nil,
                repeats: false
            )
            DDLogDebug("MainScreen: Restarted onGoingEventScheduleTimer for next event at \(nextEventTime)")
        }
    }

    /// Restarts the status animation timer
    private func restartStatusAnimationTimer() {
        statusAnimationTimer?.invalidate()

        // Start status animation timer using existing method
        statusAnimationTimer = Timer.scheduledTimer(
            timeInterval: 10,
            target: self,
            selector: #selector(animateTodayStatus),
            userInfo: nil,
            repeats: true
        )
        DDLogDebug("MainScreen: Restarted statusAnimationTimer")
    }

    /// Restarts the weather display timer
    private func restartWeatherDisplayTimer() {
        weatherDisplayTimer?.invalidate()

        // Reset to detailed view when starting the timer
        weatherDisplayMode = .detailed

        // Start weather display timer using existing method
        weatherDisplayTimer = Timer.scheduledTimer(
            timeInterval: 10,
            target: self,
            selector: #selector(updateWeatherDisplay),
            userInfo: nil,
            repeats: true
        )
        DDLogDebug("MainScreen: Restarted weatherDisplayTimer")
    }

    // MARK: - UI Type Helper Methods

    /// Determines if the given UI type is a landscape layout
    /// - Parameter uiType: The UI type to check
    /// - Returns: True if landscape layout, false if portrait
    private func isLandscapeLayout(uiType: Int) -> Bool {
        switch uiType {
        case 1,
             2,
             5:
            // UI Types 1, 2, 5: Landscape layouts
            return true
        case 3,
             4,
             6:
            // UI Types 3, 4, 6: Portrait layouts
            return false
        default:
            // Unknown UI type - default to landscape for safety
            DDLogDebug("MainScreen: Unknown UI type \(uiType), defaulting to landscape layout")
            return true
        }
    }

    /// Restarts the scrollbar timer
    private func restartScrollbarTimer() {
        scrollbarTimer?.invalidate()

        // Start scrollbar timer for scrolling messages
        if !scrollableText.isEmpty {
            scrollbarTimer = Timer.scheduledTimer(timeInterval: 4, target: self, selector: #selector(animateScrollingMessage), userInfo: nil, repeats: true)
            DDLogDebug("MainScreen: Restarted scrollbarTimer")
        }
    }

    /// Restarts the carousel timer
    private func restartCarouselTimer() {
        carousalImageTimer?.invalidate()

        // Start carousel timer if we have images using existing method
        if !carousalImageArray.isEmpty {
            carousalImageTimer = Timer.scheduledTimer(
                timeInterval: 8.0,
                target: self,
                selector: #selector(advanceToNextSlide),
                userInfo: nil,
                repeats: false
            )
            DDLogDebug("MainScreen: Restarted carousalImageTimer")
        }
    }

    private func configureCornerRadius() {
        // Configure header view - only bottom left and bottom right corners
        headerView.layer.cornerRadius = 0
        headerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        headerView.layer.cornerRadius = 25

        // Configure footer view - only top left and top right corners
        footerView.layer.cornerRadius = 0
        footerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        footerView.layer.cornerRadius = 25
    }

    private func setupCarouselFullWidthConstraints() {
        guard let carousel = carousalView,
              let centerView = centerContentView
        else {
            return
        }

        // Create full width constraints relative to centerContentView
        carousel.translatesAutoresizingMaskIntoConstraints = false

        let fullWidthConstraints = [
            carousel.leadingAnchor.constraint(equalTo: centerView.leadingAnchor, constant: 15),
            carousel.trailingAnchor.constraint(equalTo: centerView.trailingAnchor, constant: -15),
            carousel.topAnchor.constraint(equalTo: centerView.topAnchor),
            carousel.bottomAnchor.constraint(equalTo: centerView.bottomAnchor),
        ]

        carouselFullWidthConstraints = fullWidthConstraints

        // Create full width shadow constraints to match carousel
        if let shadowView = carousalShadowView {
            shadowView.translatesAutoresizingMaskIntoConstraints = false

            let shadowFullWidthConstraints = [
                shadowView.leadingAnchor.constraint(equalTo: centerView.leadingAnchor, constant: 15),
                shadowView.trailingAnchor.constraint(equalTo: centerView.trailingAnchor, constant: -15),
                shadowView.topAnchor.constraint(equalTo: centerView.topAnchor, constant: 3),
                shadowView.bottomAnchor.constraint(equalTo: centerView.bottomAnchor, constant: -3),
            ]

            carouselShadowFullWidthConstraints = shadowFullWidthConstraints
        }
    }

    private func activateCarouselFullWidthLayout() {
        guard let carousel = carousalView else {
            DDLogDebug(
                "Mainscreen : Cannot activate full width - carousel not available"
            )
            return
        }

        // Prevent full-width activation for UI Types 1 and 2
        if actualUIType == 1 || actualUIType == 2 {
            return
        }

        // Deactivate ALL existing carousel constraints before applying full-width layout
        deactivateAllCarouselConstraints()

        // Create full width constraints
        setupCarouselFullWidthConstraints()

        // Activate full width constraints
        DDLogDebug(
            "Mainscreen : Activating \(carouselFullWidthConstraints.count) full width constraints"
        )
        if carouselFullWidthConstraints.isEmpty {
            DDLogDebug("Mainscreen : ERROR - No full width constraints to activate! Check setupCarouselFullWidthConstraints()")
            return
        }
        NSLayoutConstraint.activate(carouselFullWidthConstraints)

        // Activate full width shadow constraints
        if !carouselShadowFullWidthConstraints.isEmpty {
            DDLogDebug(
                "Mainscreen : Activating \(carouselShadowFullWidthConstraints.count) shadow full width constraints"
            )
            NSLayoutConstraint.activate(carouselShadowFullWidthConstraints)
        }

        // Force layout update
        carousel.superview?.setNeedsLayout()
        carousel.superview?.layoutIfNeeded()

        // Update shadow path for carousel and its shadow view
        DispatchQueue.main.async { [weak self] in
            if let shadowView = self?.carousalShadowView {
                shadowView.layer.shadowPath = UIBezierPath(rect: shadowView.bounds).cgPath
            }
            carousel.layer.shadowPath = UIBezierPath(rect: carousel.bounds).cgPath
        }

        DDLogDebug(
            "Mainscreen : Activated carousel full width layout and forced layout update"
        )
    }

    /// Restore carousel to specific UI Type using stored constraints
    private func restoreCarouselToUIType(_ uiType: Int) {
        guard let carousel = carousalView,
              let centerView = centerContentView
        else {
            DDLogDebug("Mainscreen : Cannot restore layout - carousel or centerView not available")
            return
        }

        // Deactivate ALL existing carousel constraints
        deactivateAllCarouselConstraints()

        // Use stored constraints if available, otherwise create new ones
        let targetConstraints: [NSLayoutConstraint]
        let targetShadowConstraints: [NSLayoutConstraint]

        if !carouselUIType1Constraints.isEmpty {
            targetConstraints = carouselUIType1Constraints
            targetShadowConstraints = carouselShadowUIType1Constraints
        } else {
            carousel.translatesAutoresizingMaskIntoConstraints = false

            targetConstraints = [
                carousel.trailingAnchor.constraint(equalTo: centerView.trailingAnchor, constant: -340),
                carousel.leadingAnchor.constraint(equalTo: centerView.leadingAnchor, constant: 60),
                carousel.topAnchor.constraint(equalTo: centerView.topAnchor, constant: 20),
                carousel.bottomAnchor.constraint(equalTo: centerView.bottomAnchor, constant: -20),
            ]

            // Create shadow constraints if shadow view exists
            if let shadowView = carousalShadowView {
                shadowView.translatesAutoresizingMaskIntoConstraints = false
                targetShadowConstraints = [
                    shadowView.trailingAnchor.constraint(equalTo: centerView.trailingAnchor, constant: -340),
                    shadowView.leadingAnchor.constraint(equalTo: centerView.leadingAnchor, constant: 60),
                    shadowView.topAnchor.constraint(equalTo: centerView.topAnchor, constant: 23),
                    shadowView.bottomAnchor.constraint(equalTo: centerView.bottomAnchor, constant: -17),
                ]
            } else {
                targetShadowConstraints = []
            }

            // Store these constraints for future use
            carouselUIType1Constraints = targetConstraints
            carouselShadowUIType1Constraints = targetShadowConstraints
        }

        // Set required priority for carousel constraints
        for constraint in targetConstraints {
            constraint.priority = UILayoutPriority.required
        }

        // Set required priority for shadow constraints
        for constraint in targetShadowConstraints {
            constraint.priority = UILayoutPriority.required
        }

        // Activate the carousel constraints
        NSLayoutConstraint.activate(targetConstraints)
        DDLogDebug("Mainscreen : Activated \(targetConstraints.count) UI Type \(uiType) carousel constraints")

        // Activate the shadow constraints
        if !targetShadowConstraints.isEmpty {
            NSLayoutConstraint.activate(targetShadowConstraints)
            DDLogDebug("Mainscreen : Activated \(targetShadowConstraints.count) UI Type \(uiType) shadow constraints")
        }

        // Verify constraints are active
        for (index, constraint) in targetConstraints.enumerated() {
            DDLogDebug("Mainscreen : Carousel constraint \(index) active: \(constraint.isActive) - \(constraint)")
        }

        for (index, constraint) in targetShadowConstraints.enumerated() {
            DDLogDebug("Mainscreen : Shadow constraint \(index) active: \(constraint.isActive) - \(constraint)")
        }

        // Set manual frame as backup - this ensures proper sizing even if constraints fail
        let manualFrame = CGRect(x: 60.0, y: 20.0, width: 1460.0, height: 800.0)
        carousel.frame = manualFrame
        DDLogDebug("Mainscreen : Setting manual carousel frame as backup - \(manualFrame)")

        // Also set manual frame for shadow view with aggressive constraint cleanup
        if let shadowView = carousalShadowView {
            DDLogDebug("Mainscreen : Starting aggressive shadow constraint cleanup")

            // Force remove any autoresizing constraints
            shadowView.translatesAutoresizingMaskIntoConstraints = false

            // Remove ALL constraints involving the shadow view from ALL possible superviews
            var allShadowConstraintsToRemove: [NSLayoutConstraint] = []

            // Check main view
            let mainShadowConstraints = view.constraints.filter { constraint in
                constraint.firstItem === shadowView || constraint.secondItem === shadowView
            }
            allShadowConstraintsToRemove.append(contentsOf: mainShadowConstraints)

            // Check centerView
            let centerShadowConstraints = centerView.constraints.filter { constraint in
                constraint.firstItem === shadowView || constraint.secondItem === shadowView
            }
            allShadowConstraintsToRemove.append(contentsOf: centerShadowConstraints)

            // Check shadow's direct superview
            if let shadowSuperview = shadowView.superview {
                let superShadowConstraints = shadowSuperview.constraints.filter { constraint in
                    constraint.firstItem === shadowView || constraint.secondItem === shadowView
                }
                allShadowConstraintsToRemove.append(contentsOf: superShadowConstraints)

                // Also check for shadow-to-carousel constraints
                let shadowToCarouselConstraints = shadowSuperview.constraints.filter { constraint in
                    (constraint.firstItem === shadowView && constraint.secondItem === carousel) ||
                        (constraint.firstItem === carousel && constraint.secondItem === shadowView)
                }
                allShadowConstraintsToRemove.append(contentsOf: shadowToCarouselConstraints)
            }

            // Remove duplicates and deactivate all found constraints
            let uniqueConstraints = Array(Set(allShadowConstraintsToRemove))
            if !uniqueConstraints.isEmpty {
                DDLogDebug("Mainscreen : Forcefully removing \(uniqueConstraints.count) shadow constraints from all superviews")
                NSLayoutConstraint.deactivate(uniqueConstraints)
            }

            // Force the shadow frame to match carousel's actual frame exactly
            let carouselFrame = carousel.frame
            let shadowFrame = CGRect(x: carouselFrame.origin.x, y: carouselFrame.origin.y, width: carouselFrame.width, height: carouselFrame.height)
            shadowView.frame = shadowFrame
            DDLogDebug("Mainscreen : Force setting shadow frame to match carousel frame: \(carouselFrame)")
            DDLogDebug("Mainscreen : Set shadow frame to: \(shadowFrame)")

            // Also try setting bounds as additional backup
            shadowView.bounds = CGRect(x: 0, y: 0, width: carouselFrame.width, height: carouselFrame.height)
            DDLogDebug("Mainscreen : Force setting shadow bounds to match carousel - \(shadowView.bounds)")
        }

        // Force immediate layout update
        carousel.setNeedsUpdateConstraints()
        carousel.updateConstraintsIfNeeded()
        centerView.setNeedsLayout()
        centerView.layoutIfNeeded()
        carousel.setNeedsLayout()
        carousel.layoutIfNeeded()

        // Force layout update on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            centerView.setNeedsLayout()
            centerView.layoutIfNeeded()
            carousel.setNeedsLayout()
            carousel.layoutIfNeeded()

            // Also force shadow layout update
            if let shadowView = carousalShadowView {
                shadowView.setNeedsLayout()
                shadowView.layoutIfNeeded()

                // Force shadow frame to match carousel's actual frame exactly
                let carouselFrame = carousel.frame
                let shadowFrame = CGRect(x: carouselFrame.origin.x, y: carouselFrame.origin.y, width: carouselFrame.width, height: carouselFrame.height)
                shadowView.frame = shadowFrame
                shadowView.bounds = CGRect(x: 0, y: 0, width: carouselFrame.width, height: carouselFrame.height)

                DDLogDebug("Mainscreen : Matching shadow to carousel frame: \(carouselFrame)")
                DDLogDebug("Mainscreen : Set shadow frame to: \(shadowFrame)")

                DDLogDebug("Mainscreen : Final shadow frame after UI Type \(uiType) restoration: \(shadowView.frame)")
                DDLogDebug("Mainscreen : Final shadow bounds after UI Type \(uiType) restoration: \(shadowView.bounds)")

                // Update shadow path to match new bounds
                shadowView.layer.shadowPath = UIBezierPath(rect: shadowView.bounds).cgPath
                DDLogDebug("Mainscreen : Updated shadow path for new bounds: \(shadowView.bounds)")

                // Also force one more layout pass with a slight delay to ensure frame sticks
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard self != nil else {
                        return
                    }

                    // Match shadow to carousel's final frame after all layout is complete
                    let finalCarouselFrame = carousel.frame
                    let finalShadowFrame = CGRect(x: finalCarouselFrame.origin.x, y: finalCarouselFrame.origin.y, width: finalCarouselFrame.width, height: finalCarouselFrame.height)
                    shadowView.frame = finalShadowFrame
                    shadowView.bounds = CGRect(x: 0, y: 0, width: finalCarouselFrame.width, height: finalCarouselFrame.height)
                    // Update shadow path again after delayed frame change
                    shadowView.layer.shadowPath = UIBezierPath(rect: shadowView.bounds).cgPath
                    DDLogDebug("Mainscreen : Delayed shadow frame enforcement - matching carousel: \(finalCarouselFrame)")
                    DDLogDebug("Mainscreen : Delayed shadow frame set to: \(shadowView.frame)")
                    DDLogDebug("Mainscreen : Delayed shadow path update: \(shadowView.bounds)")
                }
            }

            DDLogDebug("Mainscreen : Final carousel frame after UI Type \(uiType) restoration: \(carousel.frame)")
        }
    }

    /// Deactivate all carousel and shadow constraints from all possible superviews
    private func deactivateAllCarouselConstraints() {
        guard let carousel = carousalView,
              let centerView = centerContentView
        else {
            return
        }

        // Deactivate stored constraint arrays
        NSLayoutConstraint.deactivate(carouselFullWidthConstraints)
        carouselFullWidthConstraints.removeAll()
        NSLayoutConstraint.deactivate(carouselShadowFullWidthConstraints)
        carouselShadowFullWidthConstraints.removeAll()

        // Find and deactivate ALL constraints that involve the carousel from any superview
        var allCarouselConstraints: [NSLayoutConstraint] = []

        // Check centerView constraints for carousel
        let centerConstraints = centerView.constraints.filter { constraint in
            constraint.firstItem === carousel || constraint.secondItem === carousel
        }
        allCarouselConstraints.append(contentsOf: centerConstraints)

        // Check centerView constraints for shadow
        if let shadowView = carousalShadowView {
            let centerShadowConstraints = centerView.constraints.filter { constraint in
                constraint.firstItem === shadowView || constraint.secondItem === shadowView
            }
            allCarouselConstraints.append(contentsOf: centerShadowConstraints)
        }

        // Check carousel's superview constraints
        if let superview = carousel.superview {
            let superConstraints = superview.constraints.filter { constraint in
                constraint.firstItem === carousel || constraint.secondItem === carousel
            }
            allCarouselConstraints.append(contentsOf: superConstraints)
        }

        // Check shadow's superview constraints
        if let shadowView = carousalShadowView, let superview = shadowView.superview {
            let superShadowConstraints = superview.constraints.filter { constraint in
                constraint.firstItem === shadowView || constraint.secondItem === shadowView
            }
            allCarouselConstraints.append(contentsOf: superShadowConstraints)
        }

        // Check main view constraints
        let mainConstraints = view.constraints.filter { constraint in
            constraint.firstItem === carousel || constraint.secondItem === carousel
        }
        allCarouselConstraints.append(contentsOf: mainConstraints)

        // Deactivate all found constraints
        if !allCarouselConstraints.isEmpty {
            NSLayoutConstraint.deactivate(allCarouselConstraints)
        }
    }

    // MARK: - Early Constraint Capture

    /// Store original UI Type constraints from storyboard before any modifications
    private func storeOriginalUITypeConstraints() {
        guard let carousel = carousalView,
              let centerView = centerContentView,
              !hasStoredOriginalConstraints
        else {
            DDLogDebug("Mainscreen : Cannot store original constraints - carousel/centerView not available or already stored")
            return
        }

        DDLogDebug("Mainscreen : Storing original UI Type constraints from storyboard")

        // Only capture if we haven't modified constraints yet (i.e., we're in original state)
        let currentConstraints = centerView.constraints.filter { constraint in
            constraint.firstItem === carousel || constraint.secondItem === carousel
        }

        DDLogDebug("Mainscreen : Found \(currentConstraints.count) original carousel constraints to store")

        // Store these as UI Type 1 constraints (the default storyboard layout)
        carouselUIType1Constraints = currentConstraints

        // Store original shadow constraints if shadow view exists
        if let shadowView = carousalShadowView {
            // Check constraints in centerView
            let centerShadowConstraints = centerView.constraints.filter { constraint in
                constraint.firstItem === shadowView || constraint.secondItem === shadowView
            }

            // Check constraints in shadow's superview (might be different from centerView)
            var allShadowConstraints = centerShadowConstraints
            if let shadowSuperview = shadowView.superview, shadowSuperview !== centerView {
                let superShadowConstraints = shadowSuperview.constraints.filter { constraint in
                    constraint.firstItem === shadowView || constraint.secondItem === shadowView
                }
                allShadowConstraints.append(contentsOf: superShadowConstraints)
                DDLogDebug("Mainscreen : Found \(superShadowConstraints.count) shadow constraints in shadow's superview")
            }

            // Check for shadow-to-carousel constraints
            if let shadowSuperview = shadowView.superview {
                let shadowToCarouselConstraints = shadowSuperview.constraints.filter { constraint in
                    (constraint.firstItem === shadowView && constraint.secondItem === carousel) ||
                        (constraint.firstItem === carousel && constraint.secondItem === shadowView)
                }
                allShadowConstraints.append(contentsOf: shadowToCarouselConstraints)
                DDLogDebug("Mainscreen : Found \(shadowToCarouselConstraints.count) shadow-to-carousel constraints")
            }

            DDLogDebug("Mainscreen : Found \(allShadowConstraints.count) total original shadow constraints to store")
            carouselShadowUIType1Constraints = allShadowConstraints

            // Create UI Type 2 shadow constraints (same as UI Type 1)
            shadowView.translatesAutoresizingMaskIntoConstraints = false

            DDLogDebug("Mainscreen : Created UI Type 2 shadow constraints")
        }

        hasStoredOriginalConstraints = true
        DDLogDebug("Mainscreen : Successfully stored original UI Type constraints")
    }

    private func captureOriginalSaraAlertConstraints() {
        guard let saraAlert = saraAlertView,
              let centerView = centerContentView
        else {
            return
        }

        // Find constraints related to SARA Alert from all possible superviews
        var allOriginalConstraints: [NSLayoutConstraint] = []

        // Check centerView constraints
        let centerConstraints = centerView.constraints.filter { constraint in
            constraint.firstItem === saraAlert || constraint.secondItem === saraAlert
        }
        allOriginalConstraints.append(contentsOf: centerConstraints)

        // Check saraAlert's superview constraints
        if let superview = saraAlert.superview {
            let superConstraints = superview.constraints.filter { constraint in
                constraint.firstItem === saraAlert || constraint.secondItem === saraAlert
            }
            allOriginalConstraints.append(contentsOf: superConstraints)
        }

        // Check main view constraints
        let mainConstraints = view.constraints.filter { constraint in
            constraint.firstItem === saraAlert || constraint.secondItem === saraAlert
        }
        allOriginalConstraints.append(contentsOf: mainConstraints)

        saraAlertOriginalConstraints = allOriginalConstraints
        DDLogDebug("Mainscreen : Captured \(saraAlertOriginalConstraints.count) original SARA Alert constraints")
    }

    private func createSaraAlertFullWidthConstraints() {
        guard let saraAlert = saraAlertView,
              let centerView = centerContentView
        else {
            return
        }

        // Create full width constraints matching carousel layout
        let fullWidthConstraints = [
            saraAlert.leadingAnchor.constraint(
                equalTo: centerView.leadingAnchor,
                constant: 15
            ),
            saraAlert.trailingAnchor.constraint(
                equalTo: centerView.trailingAnchor,
                constant: -15
            ),
            saraAlert.topAnchor.constraint(equalTo: centerView.topAnchor),
            saraAlert.bottomAnchor.constraint(equalTo: centerView.bottomAnchor),
        ]

        saraAlertFullWidthConstraints = fullWidthConstraints
        DDLogDebug("Mainscreen : Created \(saraAlertFullWidthConstraints.count) SARA Alert full width constraints")
    }

    /// Deactivate all SARA alert constraints from all possible superviews
    private func deactivateAllSaraAlertConstraints() {
        guard let saraAlert = saraAlertView,
              let centerView = centerContentView
        else {
            return
        }

        // Deactivate stored full-width constraint array
        NSLayoutConstraint.deactivate(saraAlertFullWidthConstraints)
        saraAlertFullWidthConstraints.removeAll()

        // Don't clear saraAlertOriginalConstraints - we need them for restoration

        // Find and deactivate ALL constraints that involve the SARA alert from any superview
        var allSaraAlertConstraints: [NSLayoutConstraint] = []

        // Check centerView constraints for SARA alert
        let centerConstraints = centerView.constraints.filter { constraint in
            constraint.firstItem === saraAlert || constraint.secondItem === saraAlert
        }
        allSaraAlertConstraints.append(contentsOf: centerConstraints)

        // Check SARA alert's superview constraints
        if let superview = saraAlert.superview {
            let superConstraints = superview.constraints.filter { constraint in
                constraint.firstItem === saraAlert || constraint.secondItem === saraAlert
            }
            allSaraAlertConstraints.append(contentsOf: superConstraints)
        }

        // Check main view constraints
        let mainConstraints = view.constraints.filter { constraint in
            constraint.firstItem === saraAlert || constraint.secondItem === saraAlert
        }
        allSaraAlertConstraints.append(contentsOf: mainConstraints)

        // Deactivate all found constraints
        if !allSaraAlertConstraints.isEmpty {
            DDLogDebug("Mainscreen : Deactivating \(allSaraAlertConstraints.count) total SARA Alert constraints from all superviews")
            NSLayoutConstraint.deactivate(allSaraAlertConstraints)
        }
    }

    private func activateSaraAlertFullWidthLayout() {
        guard let saraAlert = saraAlertView else {
            DDLogDebug(
                "Mainscreen : Cannot activate SARA Alert full width - view not available"
            )
            return
        }

        // Store original constraints if not already stored (before any deactivation)
        if saraAlertOriginalConstraints.isEmpty {
            captureOriginalSaraAlertConstraints()
        }

        // Deactivate ALL existing SARA alert constraints comprehensively
        deactivateAllSaraAlertConstraints()

        // Create full width constraints
        createSaraAlertFullWidthConstraints()

        // Activate full width constraints
        DDLogDebug(
            "Mainscreen : Activating \(saraAlertFullWidthConstraints.count) SARA Alert full width constraints"
        )
        NSLayoutConstraint.activate(saraAlertFullWidthConstraints)

        // Force layout update
        saraAlert.superview?.setNeedsLayout()
        saraAlert.superview?.layoutIfNeeded()

        // Update shadow path for new layout bounds
        DispatchQueue.main.async {
            saraAlert.layer.shadowPath = UIBezierPath(rect: saraAlert.bounds).cgPath
        }

        DDLogDebug(
            "Mainscreen : Activated SARA Alert full width layout and forced layout update"
        )
    }

    private func restoreSaraAlertOriginalLayout() {
        guard let saraAlert = saraAlertView else {
            DDLogDebug(
                "Mainscreen : Cannot restore SARA Alert layout - view not available"
            )
            return
        }

        // Store original constraints if not captured yet
        if saraAlertOriginalConstraints.isEmpty {
            captureOriginalSaraAlertConstraints()
            // If we just captured them, they're already active, no need to restore
            return
        }

        // Deactivate all current constraints comprehensively
        deactivateAllSaraAlertConstraints()

        // Reactivate original constraints
        DDLogDebug(
            "Mainscreen : Reactivating \(saraAlertOriginalConstraints.count) original SARA Alert constraints"
        )
        NSLayoutConstraint.activate(saraAlertOriginalConstraints)

        // Force layout update
        saraAlert.superview?.setNeedsLayout()
        saraAlert.superview?.layoutIfNeeded()

        // Update shadow path for restored layout bounds
        DispatchQueue.main.async {
            saraAlert.layer.shadowPath = UIBezierPath(rect: saraAlert.bounds).cgPath
        }

        DDLogDebug(
            "Mainscreen : Restored SARA Alert original layout and forced layout update"
        )
    }

    private func updateCarouselViewWithImage(
        _ image: UIImage,
        name: String,
        hasAudio: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let carousalView else {
                DDLogDebug("Mainscreen : Carousel view not available")
                return
            }

            // Batch UI updates to reduce redraw cycles
            let updateBlock = {
                carousalView.image = image
                self.carouselImageSubject.send(image)

                // Audio icon management
                if hasAudio {
                    DDLogDebug("Mainscreen : Carousel has audio - \(name)")
                    self.updateAudioIcon(for: carousalView)
                } else {
                    self.removeAudioIcon(from: carousalView)
                }
            }

            // Use transition for visual smoothness
            UIView.transition(
                with: carousalView,
                duration: 0.3,
                options: [.transitionCrossDissolve],
                animations: updateBlock
            )
        }
    }

    private func updateAudioIcon(for view: UIView) {
        // Remove existing audio icons first
        removeAudioIcon(from: view)

        // Initialize class-level shared icon if needed
        if MainScreenViewController.cachedIconImage == nil {
            MainScreenViewController.cachedIconImage = UIImage(
                systemName: "speaker.wave.2.fill"
            )?.withTintColor(.white, renderingMode: .alwaysOriginal)
        }

        guard let iconImage = MainScreenViewController.cachedIconImage else {
            DDLogDebug("Mainscreen: Failed to load icon image")
            return
        }

        // Create icon components
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 20
        blurView.layer.masksToBounds = true
        blurView.tag = 999
        view.addSubview(blurView)

        let audioIcon = UIImageView(image: iconImage)
        audioIcon.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(audioIcon)

        // Position with constants to reduce calculation overhead
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: 20
            ),
            blurView.rightAnchor.constraint(
                equalTo: view.rightAnchor,
                constant: -20
            ),
            blurView.widthAnchor.constraint(equalToConstant: 60),
            blurView.heightAnchor.constraint(equalToConstant: 60),

            audioIcon.centerXAnchor.constraint(
                equalTo: blurView.contentView.centerXAnchor
            ),
            audioIcon.centerYAnchor.constraint(
                equalTo: blurView.contentView.centerYAnchor
            ),
            audioIcon.widthAnchor.constraint(equalToConstant: 40),
            audioIcon.heightAnchor.constraint(equalToConstant: 33.33), // 40/1.2
        ])

        // Store reference for quicker access later
        audioIconView = blurView
    }

    private func removeAudioIcon(from view: UIView) {
        // Use the stored reference if available for faster removal
        if let storedIcon = audioIconView, storedIcon.superview == view {
            storedIcon.removeFromSuperview()
            audioIconView = nil
            return
        }

        // Fallback to standard search if reference is stale
        for subview in view.subviews {
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }
    }

    private func preloadNextCarouselSlide() {
        if isPreloadingNextSlide || carousalImageArray.isEmpty {
            return // Avoid multiple concurrent preloads
        }

        isPreloadingNextSlide = true

        // Calculate next slide index
        let nextIndex = (imageCount + 1) % carousalImageArray.count
        let nextImageData = carousalImageArray[nextIndex].0
        let nextImageName = carousalImageArray[nextIndex].2

        // Check if already cached
        let cacheKey = NSString(string: nextImageName)
        if imageCache.object(forKey: cacheKey) != nil {
            isPreloadingNextSlide = false
            return // Already cached, no need to preload
        }

        // Preload in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else {
                return
            }

            if let nextImage = UIImage(data: nextImageData, scale: 1.0) {
                imageCache.setObject(nextImage, forKey: cacheKey)
                DDLogDebug(
                    "Mainscreen: Preloaded next carousel image: \(nextImageName)"
                )
            } else {
                DDLogDebug(
                    "Mainscreen: Failed to preload next carousel image: \(nextImageName)"
                )
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                isPreloadingNextSlide = false
            }
        }
    }

    private func handleOfflineCarouselUpdate() {
        DDLogDebug("Mainscreen: Network unavailable during carousel update")

        let imageData = carousalImageArray[imageCount].0
        let carouselSlotTime = carousalImageArray[imageCount].1
        let carouselName = carousalImageArray[imageCount].2

        let finalDuration = max(Double(carouselSlotTime), 10.0)

        if imageData.isEmpty {
            DDLogDebug("Mainscreen : Carousel image data not available")
            presentDefaultSlide()
            return
        }

        // Use cached image if available
        let cacheKey = NSString(string: carouselName)
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            DDLogDebug(
                "Mainscreen: Offline mode - using cached image for \(carouselName)"
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                updateCarouselViewWithImage(
                    cachedImage,
                    name: carouselName,
                    hasAudio: false
                )
            }
        } else if let image = UIImage(data: imageData, scale: 1.0) {
            // Cache the newly created image
            imageCache.setObject(image, forKey: cacheKey)
            DDLogDebug(
                "Mainscreen: Offline mode - created and cached image for \(carouselName)"
            )
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                updateCarouselViewWithImage(
                    image,
                    name: carouselName,
                    hasAudio: false
                )
            }
        } else {
            DDLogDebug(
                "Mainscreen: Offline mode - image could not be created from data"
            )
            presentDefaultSlide()
            return
        }

        carousalImageTimer?.invalidate()

        // Schedule the next slide using a default duration
        DDLogDebug(
            "Mainscreen: Offline mode - scheduling next slide in \(finalDuration) seconds using DispatchQueue"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + finalDuration) {
            [weak self] in
            guard let self else {
                return
            }

            DDLogDebug("Mainscreen: Offline mode - advancing to next slide")
            advanceToNextSlideWithAdvertisements()
        }
    }

    private func handleCarouselAudio(
        audioURLString: String,
        currentSlideIndex: Int,
        carouselSlotTime: Int
    ) {
        // Set a reasonable default, e.g., 3 seconds
        let minimumSlotTime = 3.0
        let newSlotTime = max(Double(carouselSlotTime), minimumSlotTime)

        // Check if there's an audio URL (narration)
        if audioURLString.isEmpty {
            narrationAudioPlayer.stopCurrentAudio()
            isNarrationPlaying = false

            DDLogDebug(
                "Mainscreen : Carousel has no narration, using the slot time as \(newSlotTime)"
            )
            scheduleNextSlide(with: newSlotTime)

            // Handle radio resumption
            handleRadioResumption()
        } else {
            // Has audio URL, check network
            if !isNetworkReachable {
                DDLogDebug(
                    "Mainscreen: Network is not reachable, skipping narration and using default duration"
                )
                let slotTime = max(Double(carouselSlotTime), 5.0)
                scheduleNextSlide(with: slotTime)
                handleRadioForOfflineMode()
            } else {
                // Network available, handle narration
                handleNarration(
                    audioURLString: audioURLString,
                    currentSlideIndex: currentSlideIndex,
                    newSlotTime: newSlotTime
                )
            }
        }
    }

    private func handleNarration(
        audioURLString: String,
        currentSlideIndex: Int,
        newSlotTime: Double
    ) {
        // Pause radio if needed
        if radioConnection.radioPlayingStatus ?? false {
            radioConnection.isRadioPausedDueToNarration = true
            radioConnection.radioPlayingStatus = false
            isRadioPlayingSubject.send(false)
            radioConnection.stopRadio()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                updateRadioIcon(status: false, isNetworkDown: false)
            }
            DDLogDebug("Mainscreen : Radio off, due to Carousel Narration")
        }

        // Check if we're already playing a narration for this slide
        if narrationAudioPlayer.isPlayingForSlide(currentSlideIndex) {
            DDLogDebug(
                "Mainscreen: Narration already playing for slide \(currentSlideIndex), not restarting"
            )
            return
        }

        // Flag narration as playing before requesting the audio
        isNarrationPlaying = true

        // Pass the current slide index to the narration player
        narrationAudioPlayer.playAudio(
            from: audioURLString,
            forSlideIndex: currentSlideIndex,
            completion: { [weak self] audioDuration in
                guard let self else {
                    return
                }

                // Check if audio downloaded successfully
                if audioDuration <= 0 {
                    DDLogDebug(
                        "Mainscreen: Audio duration is zero or negative for slide \(currentSlideIndex), using default duration"
                    )
                    // Reset narration state
                    isNarrationPlaying = false
                    // If we're still on the same slide, schedule the next one
                    if imageCount == currentSlideIndex {
                        scheduleNextSlide(with: Double(newSlotTime))
                    }
                    return
                }

                // We have a valid audio duration
                let totalDuration = audioDuration + 5.0 // Add buffer time

                // If we're still on the same slide, schedule the next one based on audio duration
                if imageCount == currentSlideIndex {
                    scheduleNextSlide(with: totalDuration)
                } else {
                    // We're already showing a different slide
                    DDLogDebug(
                        "Mainscreen: Slide already changed during audio loading (was \(currentSlideIndex), now \(imageCount))"
                    )
                }
            }
        )
    }

    private func handleRadioResumption() {
        let radioAllowedByServer = radioConnection.isRadioPlaybackAllowedByServer()
        if radioAllowedByServer, radioConnection.isRadioPausedDueToNarration,
           !radioConnection.radioPlayingStatus, !isSaraAlertPresented
        {
            radioConnection.isRadioPausedDueToNarration = false
            radioConnection.radioPlayingStatus = true
            isRadioPlayingSubject.send(true)
            radioConnection.playRadio()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                updateRadioIcon(status: true, isNetworkDown: false)
            }
            DDLogDebug(
                "Mainscreen : Radio resumed as next slide has no narration"
            )
        } else if radioConnection.isRadioPausedDueToNarration {
            DDLogDebug(
                "MainScreen: Next slide radio resume blocked - radioPlayingStatus: \(radioConnection.radioPlayingStatus ?? false), isSaraAlertPresented: \(isSaraAlertPresented), serverPlayingStatus: \(radioAllowedByServer)"
            )
        }
    }

    private func handleRadioForOfflineMode() {
        if radioConnection.radioPlayingStatus {
            radioConnection.stopRadio()
            radioConnection.radioPlayingStatus = false
            isRadioPlayingSubject.send(false)
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                updateRadioIcon(status: false, isNetworkDown: true)
            }
            DDLogDebug(
                "Mainscreen: Radio icon updated to 'down' state as network is unavailable"
            )
        }
    }

    private func handleOutOfTimeRangeRadio() {
        if isNetworkReachable {
            let radioAllowedByServer = radioConnection.isRadioPlaybackAllowedByServer()
            if radioAllowedByServer, !radioConnection.radioPlayingStatus, !isSaraAlertPresented {
                radioConnection.isRadioPausedDueToNarration = false
                radioConnection.radioPlayingStatus = true
                isRadioPlayingSubject.send(true)
                radioConnection.playRadio()
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }

                    updateRadioIcon(status: true, isNetworkDown: false)
                }
                DDLogDebug(
                    "MainScreen: Radio resumed as start and end time is not in range and network is available"
                )
            } else if !radioConnection.radioPlayingStatus {
                DDLogDebug("MainScreen: Out of time range radio resume blocked - radioPlayingStatus: \(String(describing: radioConnection.radioPlayingStatus)), isSaraAlertPresented: \(isSaraAlertPresented), serverPlayingStatus: \(String(describing: radioAllowedByServer))")
            }
        }
    }

    // MARK: - Helper Methods (Combine Related)

    private func updateCarouselAudioStatus() {
        var hasAudio = false
        if !carousalImageArray.isEmpty, imageCount < carousalImageArray.count {
            let audioURLString = carousalImageArray[imageCount].3
            hasAudio = !audioURLString.isEmpty
        }
        // Send true only if audio exists AND narration is playing
        currentCarouselHasAudioSubject.send(hasAudio && isNarrationPlaying)
    }

    /// Helper function to present the default slide
    private func presentDefaultSlide() {
        if let carousalView {
            narrationAudioPlayer.stopCurrentAudio()
            isNarrationPlaying = false

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                let defaultImage = UIImage(named: "DummyCarousal")
                carousalView.image = defaultImage
                carouselImageSubject.send(defaultImage)

                // Remove both blur view and audio icon
                for subview in carousalView.subviews {
                    if subview.tag == 999 {
                        subview.removeFromSuperview() // Remove blurView directly
                    } else if let blurView = subview as? UIVisualEffectView {
                        blurView.removeFromSuperview() // Ensure blur view is also removed
                    }
                }
            }
        }

        // Default duration
        scheduleNextSlide(with: 10.0)
    }

    /// Helper function to schedule the next slide
    private func scheduleNextSlide(with duration: Double) {
        carousalImageTimer?.invalidate()

        // Log the scheduling of the next slide
        DDLogDebug(
            "Mainscreen: Scheduling next slide timer with duration \(duration) seconds, current slide: \(imageCount)"
        )

        // Schedule the next slide
        carousalImageTimer = Timer.scheduledTimer(
            timeInterval: duration,
            target: self,
            selector: #selector(advanceToNextSlide),
            userInfo: nil,
            repeats: false
        )
    }

    @objc private func advanceToNextSlide() {
        // Use new advertisement-aware logic
        advanceToNextSlideWithAdvertisements()
    }

    // MARK: - Advertisement Carousel Logic

    /// Advances to the next slide following the 4:1 normal-to-advertisement ratio
    private func advanceToNextSlideWithAdvertisements() {
        // If we have both normal slides and advertisements, use 4:1 logic
        if !normalSlidesArray.isEmpty, !advertisementSlidesArray.isEmpty {
            // Check if it's time to show an advertisement (every 4 normal slides)
            if normalSlideCount >= 4 {
                // Show advertisement slide
                let nextAdSlide = getCurrentAdvertisementSlide()
                updateImageCountForSlide(nextAdSlide)
                normalSlideCount = 0 // Reset counter
                // Advance advertisement index for next time
                advertisementIndex = (advertisementIndex + 1) % advertisementSlidesArray.count
                DDLogDebug("Mainscreen: Showing advertisement slide, next ad index: \(advertisementIndex)")
            } else {
                // Show normal slide
                let nextNormalSlide = getCurrentNormalSlide()
                updateImageCountForSlide(nextNormalSlide)
                normalSlideCount += 1
                DDLogDebug("Mainscreen: Showing normal slide, count: \(normalSlideCount)")
            }
        } else if !normalSlidesArray.isEmpty {
            // Only normal slides available - cycle through normal slides
            let nextNormalSlide = getCurrentNormalSlide()
            updateImageCountForSlide(nextNormalSlide)
            DDLogDebug("Mainscreen: Only normal slides available")
        } else if !advertisementSlidesArray.isEmpty {
            // Only advertisement slides available - cycle through ads
            let nextAdSlide = getCurrentAdvertisementSlide()
            updateImageCountForSlide(nextAdSlide)
            advertisementIndex = (advertisementIndex + 1) % advertisementSlidesArray.count
            DDLogDebug("Mainscreen: Only advertisement slides available")
        } else {
            // Fallback to original behavior
            imageCount = (imageCount + 1) % max(carousalImageArray.count, 1)
            DDLogDebug("Mainscreen: Fallback to original carousel behavior")
        }

        DDLogDebug("Mainscreen: Final imageCount: \(imageCount)")
        changeCarousalImage()
    }

    /// Gets the current normal slide and advances the normal index
    private func getCurrentNormalSlide() -> (Data, Int, String, String) {
        guard !normalSlidesArray.isEmpty else {
            DDLogDebug("Mainscreen: Error - normalSlidesArray is empty")
            return (Data(), 10, "default", "") // Return safe default
        }

        let slide = normalSlidesArray[normalIndex]

        // For single slide scenario, keep showing the same slide until we've shown 4 slides
        // Only advance index after showing an advertisement (when normalSlideCount resets to 0)
        if normalSlidesArray.count > 1 {
            // Multiple slides: advance index normally to cycle through all slides
            normalIndex = (normalIndex + 1) % normalSlidesArray.count
        } else {
            // Single slide: only advance when we start a new cycle (after advertisement)
            if normalSlideCount == 0 {
                normalIndex = (normalIndex + 1) % normalSlidesArray.count
            }
        }

        return slide
    }

    /// Gets the current advertisement slide based on advertisementIndex
    private func getCurrentAdvertisementSlide() -> (Data, Int, String, String) {
        guard !advertisementSlidesArray.isEmpty else {
            DDLogDebug("Mainscreen: Error - advertisementSlidesArray is empty")
            return (Data(), 10, "default", "") // Return safe default
        }

        return advertisementSlidesArray[advertisementIndex]
    }

    /// Updates imageCount to point to the correct slide in the main carousel array
    private func updateImageCountForSlide(_ targetSlide: (Data, Int, String, String)) {
        // Find the slide in the main carousel array by matching image name and data
        if let mainIndex = carousalImageArray.firstIndex(where: { slide in
            slide.2 == targetSlide.2 && slide.0 == targetSlide.0 // Match by name AND data
        }) {
            imageCount = mainIndex
        } else if let mainIndex = carousalImageArray.firstIndex(where: { slide in
            slide.2 == targetSlide.2 // Fallback: match by name only
        }) {
            imageCount = mainIndex
            DDLogDebug("Mainscreen: Found slide by name fallback matching")
        } else {
            // If slide not found, advance normally
            imageCount = (imageCount + 1) % max(carousalImageArray.count, 1)
            DDLogDebug("Mainscreen: Warning - Could not find slide '\(targetSlide.2)' in main array, using fallback advancement")
        }
    }
}

// MARK: - Thread Safety

/// Queue for thread-safe access to statusIndicatorArray
private let statusIndicatorQueue = DispatchQueue(
    label: "com.statussolutions.catietv.statusIndicator",
    attributes: .concurrent
)

/// Queue for thread-safe access to eventListArray
private let eventListQueue = DispatchQueue(
    label: "com.statussolutions.catietv.eventList",
    attributes: .concurrent
)

/// Queue for thread-safe access to weather arrays
private let weatherQueue = DispatchQueue(label: "com.statussolutions.catietv.weather", attributes: .concurrent)

/// Queue for thread-safe access to carousel arrays
private let carouselQueue = DispatchQueue(label: "com.statussolutions.catietv.carousel", attributes: .concurrent)

extension MainScreenViewController {
    // MARK: - Thread-Safe Status Indicator Methods

    /// Thread-safe method to update status indicators
    func updateStatusIndicators(_ indicators: [(String, String, Int)]) {
        statusIndicatorQueue.async(flags: .barrier) { [weak self] in
            guard let self else {
                return
            }

            // Update the array on the barrier queue
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                statusIndicatorArray = indicators

                // Reload collection view on main thread
                statusIndicatorCollectionView?.reloadData()

                // Invalidate layout to recalculate smart spacing
                statusIndicatorCollectionView?.collectionViewLayout.invalidateLayout()

                // Update page control
                let pageCount =
                    indicators.isEmpty
                        ? 0 : Int(ceil(CGFloat(indicators.count) / 2.0))
                adjustStatusIndicatorPageControl(
                    withCurrentPage: 0,
                    andNumberOfPage: max(1, pageCount)
                )
            }
        }
    }

    /// Thread-safe method to get a copy of status indicators with duplicate removal
    func getStatusIndicatorsCopy() -> [(String, String, Int)] {
        var copy: [(String, String, Int)] = []
        statusIndicatorQueue.sync {
            copy = self.statusIndicatorArray
        }

        // Remove duplicates based on status title and description
        var uniqueIndicators: [(String, String, Int)] = []
        var seenIndicators: Set<String> = []

        for indicator in copy {
            let indicatorKey = "\(indicator.0)|\(indicator.1)" // title|description
            if !seenIndicators.contains(indicatorKey) {
                seenIndicators.insert(indicatorKey)
                uniqueIndicators.append(indicator)
            }
        }

        return uniqueIndicators
    }

    // MARK: - Thread-Safe Event List Methods

    /// Thread-safe method to update event list
    func updateEventList(
        _ events: [(String, String, String, String, String, Bool)]
    ) {
        eventListQueue.async(flags: .barrier) { [weak self] in
            guard let self else {
                return
            }

            DDLogDebug("Mainscreen: Updating event list with \(events.count) events and existing count \(eventListArray.count)")

            // Update the array on the barrier queue
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                eventListArray = events

                // Reload table view on main thread
                eventListTable?.reloadData()

                // Also notify portrait view with updated events
                eventListArraySubject.send(events)
            }
        }
    }

    /// Thread-safe method to get a copy of event list
    func getEventListCopy() -> [(String, String, String, String, String, Bool)] {
        var copy: [(String, String, String, String, String, Bool)] = []
        eventListQueue.sync {
            copy = self.eventListArray
        }

        return copy
    }

    /// Thread-safe method to set event list array directly without triggering UI updates
    /// Used during initial loading to avoid showing unhighlight events before highlighting is applied
    private func setEventListArrayDirectly(_ events: [(String, String, String, String, String, Bool)]) {
        eventListQueue.sync(flags: .barrier) { [weak self] in
            guard let self else {
                return
            }

            // Set the array directly without triggering UI updates
            // The didSet observer will still fire and update the portrait view subject
            eventListArray = events

            DDLogDebug("Mainscreen: Set event list directly with \(events.count) events (no UI reload)")
        }
    }

    /// Thread-safe method to get a copy of today weather with duplicate removal
    func getTodayWeatherCopy() -> [[String: String]] {
        var copy: [[String: String]] = []
        weatherQueue.sync {
            copy = self.todayWeatherArray
        }

        // Remove duplicates based on weather data keys and values
        var uniqueWeather: [[String: String]] = []
        var seenWeather: Set<String> = []

        for weather in copy {
            let weatherKey = weather.keys.sorted().map { "\($0):\(weather[$0] ?? "")" }.joined(separator: "|")
            if !seenWeather.contains(weatherKey) {
                seenWeather.insert(weatherKey)
                uniqueWeather.append(weather)
            }
        }

        return uniqueWeather
    }

    /// Thread-safe method to get a copy of forecast weather with duplicate removal
    func getForecastWeatherCopy() -> [(String, String, String, UIImage, String)] {
        var copy: [(String, String, String, UIImage, String)] = []
        weatherQueue.sync {
            copy = self.forecastWeatherArray
        }

        // Remove duplicates based on weather data
        var uniqueWeather: [(String, String, String, UIImage, String)] = []
        var seenWeather: Set<String> = []

        for weather in copy {
            let weatherKey = "\(weather.0)|\(weather.1)|\(weather.2)|\(weather.4)" // day|high|low|description
            if !seenWeather.contains(weatherKey) {
                seenWeather.insert(weatherKey)
                uniqueWeather.append(weather)
            }
        }

        return uniqueWeather
    }

    /// Thread-safe method to get a copy of carousel images with duplicate removal
    func getCarouselImagesCopy() -> [(Data, Int, String, String)] {
        var copy: [(Data, Int, String, String)] = []
        carouselQueue.sync {
            copy = self.carousalImageArray
        }

        // Remove duplicates based on image data and metadata
        var uniqueImages: [(Data, Int, String, String)] = []
        var seenImages: Set<String> = []

        for image in copy {
            let imageKey = "\(image.1)|\(image.2)|\(image.3)" // type|filename|metadata
            if !seenImages.contains(imageKey) {
                seenImages.insert(imageKey)
                uniqueImages.append(image)
            }
        }

        return uniqueImages
    }

    // MARK: - Helper function to convert 12-hour format to 24-hour format string

    func convertTo24HourFormat(_ timeString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "h:mm a"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.amSymbol = "AM"
        inputFormatter.pmSymbol = "PM"

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        outputFormatter.dateFormat = "HH:mm:ss"

        if let date = inputFormatter.date(from: timeString) {
            return outputFormatter.string(from: date)
        }

        // Fallback: if parsing fails, return original string
        DDLogDebug("Mainscreen : Failed to convert time format: \(timeString)")
        return "00:00:00"
    }
}
