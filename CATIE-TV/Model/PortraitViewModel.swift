import AVFoundation
import CocoaLumberjackSwift
import Combine
import SwiftUI

// MARK: - PortraitViewModel

class PortraitViewModel: ObservableObject {
    // MARK: Lifecycle

    init() {}

    deinit {
        cancellables.removeAll()
    }

    // MARK: Internal

    /// Model for rich text components
    struct BodyTextComponent: Identifiable {
        // MARK: Lifecycle

        init(text: String, fontSize: CGFloat = 24, fontStyle: String = "", color: Color = .black, alignment: TextAlignment = .center) {
            self.text = text
            self.fontSize = fontSize
            self.fontStyle = fontStyle
            self.color = color
            self.alignment = alignment
        }

        // MARK: Internal

        var id = UUID()
        var text: String
        var fontSize: CGFloat
        var fontStyle: String // "bold", "italic", "underline"
        var color: Color
        var alignment: TextAlignment = .center
    }

    // MARK: - Published Properties for UI binding

    @Published var uiType: Int16 = 3
    @Published var tvRadioFlag: Int = 1 // 1 = show radio, 0 = hide radio
    @Published var temperature = "--°"
    @Published var location = "Location..."
    @Published var weatherIcon: UIImage? = nil

    // View states
    @Published var isSaraAlertPresented = false
    @Published var isClockVisible = false
    @Published var isRadioPlaying = false
    @Published var isNarrationPlaying = false

    // Custom design options
    @Published var customDesign: Int = 0
    @Published var isCustomHomePageVisible = false
    @Published var customFontName = "Avenir Next"
    @Published var customFontSize = "50"

    // Weather data
    @Published var todayWeatherArray: [[String: String]] = []
    @Published var forecastWeatherArray: [(String, String, String, UIImage, String)] = []

    // Carousel
    @Published var currentCarouselImage: UIImage? = nil
    @Published var currentCarouselHasAudio = false

    // Events
    @Published var eventListArray: [(String, String, String, String, String, Bool)] = []
    @Published var isTodayActivityPresent = false

    /// Status indicators
    @Published var statusIndicatorArray: [(String, String, Int)] = []

    /// Site logo
    @Published var siteLogo: UIImage? = UIImage(named: "SS")

    @Published var scrollableText: String = ""

    /// Indicates if network is down
    @Published var isNetworkDown: Bool = false

    // SARA Alert properties
    // General alert properties
    @Published var saraAlertHeader: String = "ALERT" // Could be "ALERT" or "ALL CLEAR"
    @Published var saraAlertMessage: String = "Important information about your facility"
    @Published var saraAlertFooter: String = "Please stand by for more information"

    // Border properties
    @Published var saraAlertBorderColor: Color = .black
    @Published var saraAlertBorderWidth: CGFloat = 10.0
    @Published var saraAlertFlashing: Bool = false
    @Published var saraAlertFlashColor: Color = .black

    // Header styling
    @Published var saraAlertHeaderBackgroundColor: Color = .white
    @Published var saraAlertHeaderTextColor: Color = .black
    @Published var saraAlertHeaderFontSize: CGFloat = 40
    @Published var saraAlertHeaderFontStyle: String = "bold" // Can contain "bold", "italic", "underline"

    // Body styling
    @Published var saraAlertBodyBackgroundColor: Color = .white
    @Published var saraAlertBodyTextColor: Color = .black
    @Published var saraAlertBodyFontSize: CGFloat = 24
    @Published var saraAlertBodyFontStyle: String = "" // Can contain "bold", "italic", "underline"

    // Rich text support for body
    @Published var saraAlertHasRichText: Bool = false
    @Published var saraAlertBodyTextComponents: [BodyTextComponent] = []

    // Footer styling
    @Published var saraAlertFooterBackgroundColor: Color = .white
    @Published var saraAlertFooterTextColor: Color = .black
    @Published var saraAlertFooterFontSize: CGFloat = 18
    @Published var saraAlertFooterFontStyle: String = "" // Can contain "bold", "italic", "underline"

    @Published var clockMessage: String = ""

    @Published var headerTime: String = "--:--"
    @Published var headerDate: String = "------"

    @Published var isLoading: Bool = false

    var mainViewController: MainScreenViewController? {
        mainVC
    }

    // MARK: - Helper Methods for SARA color parsing

    /// Static color parsing method that doesn't require self reference
    static func staticParseColor(from colorString: String) -> Color {
        let trimmed = colorString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse color without caching for static calls
        return if trimmed.hasPrefix("#") {
            Color(hex: trimmed) ?? .red
        } else if trimmed.hasPrefix("rgb") {
            Color(rgbString: trimmed) ?? .red
        } else {
            // Handle named colors or fallback
            switch trimmed.lowercased() {
            case "red": .red
            case "blue": .blue
            case "green": .green
            case "yellow": .yellow
            case "black": .black
            case "white": .white
            default: .red
            }
        }
    }

    // MARK: - Public Methods

    /// Explicitly cleanup all subscriptions and references
    func cleanup() {
        cancellables.removeAll()
        mainVC = nil
        DDLogDebug("PortraitViewModel: cleanup - all subscriptions cancelled and references cleared")
    }

    /// Set up Combine subscriptions from the main view controller
    func setupSubscriptions(from controller: MainScreenViewController) {
        mainVC = controller // Store weak reference if needed elsewhere
        cancellables.removeAll() // Clear old subscriptions if any

        // Network status subscription
        controller.isNetworkDownSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isNetworkDown in
                guard let self else {
                    return
                }

                // Always update network status when received, even if it appears unchanged
                // This ensures proper state sync between UIKit and SwiftUI
                DDLogDebug("PortraitViewModel: Network status updated to \(isNetworkDown ? "down" : "up")")
                self.isNetworkDown = isNetworkDown
            }
            .store(in: &cancellables)

        // Comprehensive weather data update - combine all weather properties
        Publishers.CombineLatest4(
            controller.temperatureSubject.map { $0 ?? "--°" },
            controller.locationSubject.map { $0 ?? "Location..." },
            controller.weatherIconSubject,
            Publishers.CombineLatest(
                controller.todayWeatherArraySubject,
                controller.forecastWeatherArraySubject
            )
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] temperature, location, icon, forecastData in
            guard let self else {
                return
            }

            let (todayWeather, forecastWeather) = forecastData

            // Compare and update only if data has changed
            if self.temperature != temperature ||
                self.location != location ||
                weatherIcon != icon ||
                todayWeatherArray != todayWeather ||
                !areForecastWeatherArraysEqual(forecastWeatherArray, forecastWeather)
            {
                let transaction = Transaction(animation: nil)
                withTransaction(transaction) {
                    self.temperature = temperature
                    self.location = location
                    self.weatherIcon = icon
                    self.todayWeatherArray = todayWeather
                    self.forecastWeatherArray = forecastWeather
                }
            }
        }
        .store(in: &cancellables)

        // Enhanced carousel transition handling with better debouncing and animation coordination
        Publishers.CombineLatest(
            controller.carouselImageSubject.throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true),
            controller.currentCarouselHasAudioSubject
        )
        .receive(on: DispatchQueue.global(qos: .userInitiated)) // Process on background thread first
        .map { image, hasAudio -> (UIImage?, Bool) in
            // Pre-process images off the main thread to avoid UI blockage
            if let image {
                // Use a background thread for any expensive image operations
                // This helps prevent main thread blockage during transitions
                return (image, hasAudio)
            }
            return (image, hasAudio)
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] image, hasAudio in
            guard let self else {
                return
            }

            // Skip carousel updates when clock is visible to prevent carousel from running during clock display
            if isClockVisible {
                DDLogDebug("PortraitViewModel: Skipping carousel update while clock is visible")
                return
            }

            // Compare and update only if data has changed
            if currentCarouselImage != image || currentCarouselHasAudio != hasAudio {
                currentCarouselImage = image
                currentCarouselHasAudio = hasAudio
            }
        }
        .store(in: &cancellables)

        // Optimize event-related properties
        Publishers.CombineLatest(
            controller.eventListArraySubject,
            controller.isTodayActivityPresentSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] events, isTodayActivityPresent in
            guard let self else {
                return
            }

            // Use our new comparison method to detect any changes
            if !areEventArraysEqual(eventListArray, events) ||
                self.isTodayActivityPresent != isTodayActivityPresent
            {
                DDLogDebug("PortraitViewModel: Events data updated with \(events.count) items")

                // Use withTransaction for smoother UI updates
                let transaction = Transaction(animation: .easeInOut(duration: 0.3))
                withTransaction(transaction) {
                    self.eventListArray = events
                    self.isTodayActivityPresent = isTodayActivityPresent
                }
            }
        }
        .store(in: &cancellables)

        // Status indicators with pagination and enhanced logging
        controller.statusIndicatorArraySubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] indicators in
                guard let self else {
                    return
                }

                DDLogDebug("PortraitViewModel: Received status indicator update with \(indicators.count) items")

                // Check if the array has changed before updating using our custom comparison
                if !areStatusIndicatorArraysEqual(statusIndicatorArray, indicators) {
                    DDLogDebug("PortraitViewModel: Status indicators changed, updating UI")

                    // Log the new indicators for debugging
                    for (index, indicator) in indicators.enumerated() {
                        DDLogDebug("PortraitViewModel: Indicator \(index): \(indicator.0) | \(indicator.1) | \(indicator.2)")
                    }

                    statusIndicatorArray = indicators
                } else {
                    DDLogDebug("PortraitViewModel: Status indicators unchanged, skipping update")
                }
            }
            .store(in: &cancellables)

        controller.siteLogoSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] logo in
                guard let self else {
                    return
                }

                // Check if the logo has changed before updating
                if siteLogo != logo {
                    siteLogo = logo
                }
            }
            .store(in: &cancellables)

        // Alert visibility with throttling for performance
        controller.isSaraAlertPresentedSubject
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPresented in
                guard let self else {
                    return
                }

                // Check if the value has changed before updating
                if isSaraAlertPresented != isPresented {
                    isSaraAlertPresented = isPresented
                }
            }
            .store(in: &cancellables)

        // Combine clock-related properties
        Publishers.CombineLatest(
            controller.isClockPresentedSubject,
            controller.clockMessageSubject.map { $0 ?? "" }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isVisible, message in
            guard let self else {
                return
            }

            // Check if either value has changed before updating
            if isClockVisible != isVisible || clockMessage != message {
                let transaction = Transaction(animation: .easeInOut(duration: 0.2))
                withTransaction(transaction) {
                    self.isClockVisible = isVisible
                    self.clockMessage = message
                }
            }
        }
        .store(in: &cancellables)

        // Combine media playback states
        Publishers.CombineLatest(
            controller.isRadioPlayingSubject,
            controller.isNarrationPlayingSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isRadioPlaying, isNarrationPlaying in
            guard let self else {
                return
            }

            // Check if either value has changed before updating
            if self.isRadioPlaying != isRadioPlaying || self.isNarrationPlaying != isNarrationPlaying {
                let transaction = Transaction(animation: nil)
                withTransaction(transaction) {
                    self.isRadioPlaying = isRadioPlaying
                    self.isNarrationPlaying = isNarrationPlaying
                }
            }
        }
        .store(in: &cancellables)

        controller.scrollableTextSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else {
                    return
                }

                // Check if the text has changed before updating
                if scrollableText != text {
                    scrollableText = text
                }
            }
            .store(in: &cancellables)

        // Combine custom design properties
        Publishers.CombineLatest3(
            controller.customDesignSubject,
            controller.customFontNameSubject,
            controller.customFontSizeSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] design, fontName, fontSize in
            guard let self else {
                return
            }

            // Calculate if custom home page is visible based on design value
            let isCustomVisible = (design == 1)

            // Check if any value has changed before updating
            if customDesign != design ||
                isCustomHomePageVisible != isCustomVisible ||
                customFontName != fontName ||
                customFontSize != fontSize
            {
                let transaction = Transaction(animation: nil)
                withTransaction(transaction) {
                    self.customDesign = design
                    self.isCustomHomePageVisible = isCustomVisible
                    self.customFontName = fontName
                    self.customFontSize = fontSize
                }
            }
        }
        .store(in: &cancellables)

        // SARA ALERT COMBINE LOGIC

        // 1. Alert general properties
        Publishers.CombineLatest3(
            controller.saraAlertHeaderSubject,
            controller.saraAlertMessageSubject,
            controller.saraAlertFooterSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] header, message, footer in
            guard let self else {
                return
            }

            // Check if any value has changed before updating
            if saraAlertHeader != header ||
                saraAlertMessage != message ||
                saraAlertFooter != footer
            {
                let transaction = Transaction(animation: .easeInOut(duration: 0.2))
                withTransaction(transaction) {
                    self.saraAlertHeader = header
                    self.saraAlertMessage = message
                    self.saraAlertFooter = footer
                }
            }
        }
        .store(in: &cancellables)

        // 2. Alert border properties
        Publishers.CombineLatest3(
            controller.saraAlertBorderColorSubject.map { colorString in PortraitViewModel.staticParseColor(from: colorString) },
            controller.saraAlertBorderWidthSubject,
            controller.saraAlertFlashingSubject
        )
        .combineLatest(controller.saraAlertFlashColorSubject.map { colorString in PortraitViewModel.staticParseColor(from: colorString) })
        .receive(on: DispatchQueue.main)
        .sink { [weak self] combinedValues, flashColor in
            guard let self else {
                return
            }

            let (borderColor, borderWidth, flashing) = combinedValues

            // Check if any value has changed before updating
            // Note: Color comparison is special and might need custom equality check
            if saraAlertBorderWidth != borderWidth ||
                saraAlertFlashing != flashing ||
                !colorEquals(saraAlertBorderColor, borderColor) ||
                !colorEquals(saraAlertFlashColor, flashColor)
            {
                let transaction = Transaction(animation: .easeInOut(duration: 0.2))
                withTransaction(transaction) {
                    self.saraAlertBorderColor = borderColor
                    self.saraAlertBorderWidth = borderWidth
                    self.saraAlertFlashing = flashing
                    self.saraAlertFlashColor = flashColor
                }
            }
        }
        .store(in: &cancellables)

        // 3. Header styling
        Publishers.CombineLatest4(
            controller.saraAlertHeaderBackgroundColorSubject.map { colorString in PortraitViewModel.staticParseColor(from: colorString) },
            controller.saraAlertHeaderTextColorSubject.map { colorString in PortraitViewModel.staticParseColor(from: colorString) },
            controller.saraAlertHeaderFontSizeSubject,
            controller.saraAlertHeaderFontStyleSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] bgColor, textColor, fontSize, fontStyle in
            guard let self else {
                return
            }

            // Check if any value has changed before updating
            if !colorEquals(saraAlertHeaderBackgroundColor, bgColor) ||
                !colorEquals(saraAlertHeaderTextColor, textColor) ||
                saraAlertHeaderFontSize != fontSize ||
                saraAlertHeaderFontStyle != fontStyle
            {
                let transaction = Transaction(animation: nil)
                withTransaction(transaction) {
                    self.saraAlertHeaderBackgroundColor = bgColor
                    self.saraAlertHeaderTextColor = textColor
                    self.saraAlertHeaderFontSize = fontSize
                    self.saraAlertHeaderFontStyle = fontStyle
                }
            }
        }
        .store(in: &cancellables)

        // 4. Body styling
        Publishers.CombineLatest4(
            controller.saraAlertBodyBackgroundColorSubject.map { colorString in PortraitViewModel.staticParseColor(from: colorString) },
            controller.saraAlertBodyTextColorSubject.map { colorString in PortraitViewModel.staticParseColor(from: colorString) },
            controller.saraAlertBodyFontSizeSubject,
            controller.saraAlertBodyFontStyleSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] bgColor, textColor, fontSize, fontStyle in
            guard let self else {
                return
            }

            // Check if any value has changed before updating
            if !colorEquals(saraAlertBodyBackgroundColor, bgColor) ||
                !colorEquals(saraAlertBodyTextColor, textColor) ||
                saraAlertBodyFontSize != fontSize ||
                saraAlertBodyFontStyle != fontStyle
            {
                let transaction = Transaction(animation: nil)
                withTransaction(transaction) {
                    self.saraAlertBodyBackgroundColor = bgColor
                    self.saraAlertBodyTextColor = textColor
                    self.saraAlertBodyFontSize = fontSize
                    self.saraAlertBodyFontStyle = fontStyle
                }
            }
        }
        .store(in: &cancellables)

        // 5. Footer styling
        Publishers.CombineLatest4(
            controller.saraAlertFooterBackgroundColorSubject.map { colorString in PortraitViewModel.staticParseColor(from: colorString) },
            controller.saraAlertFooterTextColorSubject.map { colorString in PortraitViewModel.staticParseColor(from: colorString) },
            controller.saraAlertFooterFontSizeSubject,
            controller.saraAlertFooterFontStyleSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] bgColor, textColor, fontSize, fontStyle in
            guard let self else {
                return
            }

            // Check if any value has changed before updating
            if !colorEquals(saraAlertFooterBackgroundColor, bgColor) ||
                !colorEquals(saraAlertFooterTextColor, textColor) ||
                saraAlertFooterFontSize != fontSize ||
                saraAlertFooterFontStyle != fontStyle
            {
                let transaction = Transaction(animation: nil)
                withTransaction(transaction) {
                    self.saraAlertFooterBackgroundColor = bgColor
                    self.saraAlertFooterTextColor = textColor
                    self.saraAlertFooterFontSize = fontSize
                    self.saraAlertFooterFontStyle = fontStyle
                }
            }
        }
        .store(in: &cancellables)

        // 6. Rich text components
        Publishers.CombineLatest(
            controller.saraAlertHasRichTextSubject,
            controller.saraAlertBodyTextComponentsSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] hasRichText, components in
            guard let self else {
                return
            }

            // Check if values have changed before updating
            // Note: For the components array, we need to check if the arrays are logically different
            if saraAlertHasRichText != hasRichText ||
                !areBodyTextComponentsEqual(saraAlertBodyTextComponents, components)
            {
                let transaction = Transaction(animation: nil)
                withTransaction(transaction) {
                    self.saraAlertHasRichText = hasRichText
                    self.saraAlertBodyTextComponents = components
                }
            }
        }
        .store(in: &cancellables)

        Publishers.CombineLatest(
            controller.headerTimeSubject,
            controller.headerDateSubject
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] time, date in
            guard let self else {
                return
            }

            // Only update if changed to avoid unnecessary redraws
            if headerTime != time || headerDate != date {
                headerTime = time
                headerDate = date
            }
        }
        .store(in: &cancellables)

        controller.isLoadingSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else {
                    return
                }

                // Only update if loading state has changed
                if self.isLoading != isLoading {
                    self.isLoading = isLoading
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Private

    // MARK: - Combine Subscriptions

    private var cancellables = Set<AnyCancellable>()
    /// Keep a weak reference
    private weak var mainVC: MainScreenViewController?

    /// Helper function to compare arrays of tuples containing UIImage
    private func areForecastWeatherArraysEqual(
        _ lhs: [(String, String, String, UIImage, String)],
        _ rhs: [(String, String, String, UIImage, String)]
    ) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        for (index, lhsElement) in lhs.enumerated() {
            let rhsElement = rhs[index]
            if lhsElement.0 != rhsElement.0 ||
                lhsElement.1 != rhsElement.1 ||
                lhsElement.2 != rhsElement.2 ||
                lhsElement.4 != rhsElement.4 ||
                !lhsElement.3.isEqual(rhsElement.3)
            { // Compare UIImage using isEqual
                return false
            }
        }
        return true
    }

    /// Helper function to compare SwiftUI Color objects
    private func colorEquals(_ lhs: Color, _ rhs: Color) -> Bool {
        // Since SwiftUI Color doesn't have a direct equality comparison,
        // we'll use its hashValue as a proxy for comparison
        // This is not 100% accurate but should work for most cases
        // A more accurate comparison would require UIKit conversion
        lhs.hashValue == rhs.hashValue
    }

    /// Helper function to compare BodyTextComponent arrays
    private func areBodyTextComponentsEqual(
        _ lhs: [BodyTextComponent],
        _ rhs: [BodyTextComponent]
    ) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        // Create a dictionary of components based on their properties for quick comparison
        let lhsDict = Dictionary(grouping: lhs) { "\($0.text)-\($0.fontSize)-\($0.fontStyle)-\($0.color.hashValue)-\($0.alignment)" }
        let rhsDict = Dictionary(grouping: rhs) { "\($0.text)-\($0.fontSize)-\($0.fontStyle)-\($0.color.hashValue)-\($0.alignment)" }

        return lhsDict.keys == rhsDict.keys &&
            lhsDict.values.map(\.count) == rhsDict.values.map(\.count)
    }

    /// Helper function to compare arrays of status indicator tuples
    /// Allows duplicates and uses element-by-element comparison with position consideration
    private func areStatusIndicatorArraysEqual(
        _ lhs: [(String, String, Int)],
        _ rhs: [(String, String, Int)]
    ) -> Bool {
        guard lhs.count == rhs.count else {
            DDLogDebug("PortraitViewModel: Status indicator arrays have different counts: \(lhs.count) vs \(rhs.count)")
            return false
        }

        // Use element-by-element comparison to allow duplicates while detecting actual changes
        for (index, lhsElement) in lhs.enumerated() {
            let rhsElement = rhs[index]
            if lhsElement.0 != rhsElement.0 ||
                lhsElement.1 != rhsElement.1 ||
                lhsElement.2 != rhsElement.2
            {
                DDLogDebug("PortraitViewModel: Status indicator changed at index \(index): [\(lhsElement.0)|\(lhsElement.1)|\(lhsElement.2)] -> [\(rhsElement.0)|\(rhsElement.1)|\(rhsElement.2)]")
                return false
            }
        }

        DDLogDebug("PortraitViewModel: Status indicator arrays are identical (including duplicates)")
        return true
    }

    /// Helper function to compare event arrays for any changes including date/time changes
    private func areEventArraysEqual(
        _ lhs: [(String, String, String, String, String, Bool)],
        _ rhs: [(String, String, String, String, String, Bool)]
    ) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        // Use element-by-element comparison to handle duplicate events properly
        for (index, lhsElement) in lhs.enumerated() {
            let rhsElement = rhs[index]
            if lhsElement.0 != rhsElement.0 ||
                lhsElement.1 != rhsElement.1 ||
                lhsElement.2 != rhsElement.2 ||
                lhsElement.3 != rhsElement.3 ||
                lhsElement.4 != rhsElement.4 ||
                lhsElement.5 != rhsElement.5
            {
                return false
            }
        }
        return true
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0,
            opacity: 1.0
        )
    }

    init?(rgbString: String) {
        let components = rgbString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .components(separatedBy: ",")

        guard components.count == 3,
              let red = Double(components[0].trimmingCharacters(in: .whitespaces)),
              let green = Double(components[1].trimmingCharacters(in: .whitespaces)),
              let blue = Double(components[2].trimmingCharacters(in: .whitespaces))
        else {
            return nil
        }

        self.init(
            .sRGB,
            red: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0,
            opacity: 1.0
        )
    }
}
