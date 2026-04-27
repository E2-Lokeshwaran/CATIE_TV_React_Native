import CocoaLumberjackSwift
import SwiftUI

// MARK: - PortraitFooterView

struct PortraitFooterView: View {
    /// Text to be scrolled in the footer
    let scrollableText: String

    /// Whether radio is currently playing
    let isRadioPlaying: Bool

    /// Whether network is down
    let isNetworkDown: Bool

    /// Theme for styling
    let theme: PortraitTheme

    /// UI type to determine layout behavior
    let uiType: Int16

    /// Radio flag to control radio visibility
    let tvRadioFlag: Int

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                theme.footerBackground
                    .cornerRadius(25, corners: [.topLeft, .topRight])
                    .shadow(color: theme.headerShadow, radius: 5, x: 0, y: 2)
                    .accessibilityIdentifier("footerBackground")

                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        // Simplified scrolling text component
                        ContinuousScrollText(
                            text: scrollableText.replacingOccurrences(of: "\n", with: " ") + ".....",
                            textColor: theme.footerText,
                            fontSize: 24,
                            viewWidth: (geometry.size.width * (tvRadioFlag == 1 ? 0.8 : 0.9)) - (isNetworkDown ? 60 : 0)
                        )
                        .padding(.leading, isNetworkDown ? 60 : 15)
                        .frame(height: 70)
                        .accessibilityIdentifier("scrollTextContainer")
                        .frame(width: geometry.size.width * (tvRadioFlag == 1 ? 0.8 : 0.9))
                        .clipped()

                        if isNetworkDown {
                            // Network down indicator at the left
                            ZStack {
                                BlurView(style: theme.isDarkMode ? .dark : .light, accessibilityIdentifier: "footerBlurBackground")
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Image(systemName: "wifi.slash")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 35, height: 35)
                                    .foregroundColor(.red)
                                    .modifier(PulseEffect())
                            }
                            .zIndex(2)
                            .accessibilityIdentifier("networkDownIcon")
                        }
                    }

                    // Show radio icon based on tvRadioFlag
                    if tvRadioFlag == 1 {
                        Image(
                            isRadioPlaying
                                ? "Radio_On"
                                : "Radio_Off"
                        )
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .padding(.trailing, 10)
                        .accessibilityIdentifier("radioIcon")
                    }
                }
                .frame(width: geometry.size.width, height: 80)
                .alignmentGuide(VerticalAlignment.center) { d in d.height / 2 }
                .offset(y: -30)
                .accessibilityIdentifier("footerContentStack")
            }
            .accessibilityIdentifier("footerMainContainer")
        }
        .frame(width: UIScreen.main.bounds.height, height: 145)
        .accessibilityIdentifier("portraitFooterView")
    }
}

// MARK: - ContinuousScrollText

struct ContinuousScrollText: UIViewRepresentable {
    let text: String
    let textColor: Color
    let fontSize: CGFloat
    let viewWidth: CGFloat

    static func dismantleUIView(_ uiView: SimpleMarqueeLabel, coordinator _: ()) {
        DDLogDebug("PortraitFooterView: Stopping text scroll animation")
        uiView.stopScrolling()
    }

    func makeUIView(context _: Context) -> SimpleMarqueeLabel {
        let marquee = SimpleMarqueeLabel()
        marquee.accessibilityIdentifier = "continuousScrollText"

        // Set the frame based on the provided viewWidth
        marquee.frame = CGRect(x: 0, y: 0, width: viewWidth, height: 70)

        // Try multiple font options to ensure numeric characters display correctly
        let font = UIFont(name: "Poppins-Regular", size: fontSize)
            ?? UIFont(name: "AvenirNext-Medium", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
        DDLogDebug("PortraitFooterView: ContinuousScrollText makeUIView - text: '\(text)', font: \(font.fontName), fontSize: \(fontSize), viewWidth: \(viewWidth)")

        // Configure after setting the frame
        DispatchQueue.main.async {
            marquee.configure(
                text: text.isEmpty ? " " : text,
                textColor: UIColor(textColor),
                font: font
            )
        }

        return marquee
    }

    func updateUIView(_ uiView: SimpleMarqueeLabel, context _: Context) {
        // Update the frame to match the current viewWidth (important for orientation changes)
        uiView.frame = CGRect(x: 0, y: 0, width: viewWidth, height: 70)

        // Try multiple font options to ensure numeric characters display correctly
        let font = UIFont(name: "Poppins-Regular", size: fontSize)
            ?? UIFont(name: "AvenirNext-Medium", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)

        // Configure with the updated frame
        DispatchQueue.main.async {
            uiView.configure(
                text: text.isEmpty ? " " : text,
                textColor: UIColor(textColor),
                font: font
            )
        }

        // Force a scroll check after text update, especially important after loading states and orientation changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            uiView.checkForScrolling()
        }

        // Additional check for orientation changes with longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            uiView.checkForScrolling()
        }
    }
}

// MARK: - SimpleMarqueeLabel

class SimpleMarqueeLabel: UIView {
    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    deinit {
        stopScrolling()
    }

    // MARK: Internal

    override func layoutSubviews() {
        super.layoutSubviews()

        // Update scroll view frame to match current bounds
        scrollView.frame = bounds

        // Configure fade layer
        fadeLayer.frame = bounds

        // Check if text needs scrolling with a slight delay to ensure layout is complete
        DispatchQueue.main.async { [weak self] in
            self?.checkForScrolling()
        }
    }

    // MARK: - Public Methods

    func configure(text: String, textColor: UIColor, font: UIFont) {
        contentLabel.text = "     " + text
        contentLabel.textColor = textColor
        contentLabel.font = font

        // Ensure we have valid bounds before calculating sizes
        guard bounds.width > 0, bounds.height > 0 else {
            DDLogDebug("SimpleMarqueeLabel: configure called with invalid bounds: \(bounds), deferring configuration")
            // Store configuration for later when bounds are available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.configure(text: text, textColor: textColor, font: font)
            }
            return
        }

        // Set content size
        let labelSize = (text as NSString).size(withAttributes: [.font: font])

        contentLabel.frame = CGRect(x: 0, y: 0, width: labelSize.width, height: bounds.height)
        scrollView.contentSize = CGSize(width: max(labelSize.width, bounds.width) + bounds.width, height: bounds.height)

        // Check if text should scroll
        isTextTruncated = labelSize.width > bounds.width

        // Ensure the view is properly set up before checking for scrolling
        DispatchQueue.main.async { [weak self] in
            self?.checkForScrolling()
        }
    }

    func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollView.setContentOffset(.zero, animated: false)
    }

    func checkForScrolling() {
        stopScrolling()

        // Always ensure the text label is visible first
        contentLabel.isHidden = false

        // Ensure scroll view is visible
        scrollView.isHidden = false

        // Only scroll if necessary and view has proper dimensions
        guard bounds.width > 0, bounds.height > 0 else {
            DDLogDebug("SimpleMarqueeLabel: Invalid bounds, deferring scroll check - bounds: \(bounds)")
            return
        }

        // Re-calculate text truncation based on current bounds
        if let text = contentLabel.text, let font = contentLabel.font {
            let labelSize = (text as NSString).size(withAttributes: [.font: font])
            isTextTruncated = labelSize.width > bounds.width
        }

        // Add duplicate text for seamless scrolling if needed
        if isTextTruncated, contentLabel.frame.width > bounds.width {
            // Create a copy of the label after the original text for continuous scrolling
            let spacer = UIView(frame: CGRect(x: contentLabel.frame.width, y: 0, width: bounds.width, height: bounds.height))
            scrollView.addSubview(spacer)
            scrollView.contentSize = CGSize(width: contentLabel.frame.width + bounds.width, height: bounds.height)

            // Start scrolling after 5 seconds to allow users to read the beginning of the text
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.startScrolling()
            }
        }
    }

    // MARK: Private

    private let scrollView = UIScrollView()
    private let contentLabel = UILabel()
    private let fadeLayer = CAGradientLayer()
    private var scrollTimer: Timer?
    private var isTextTruncated = false

    // MARK: - Private Methods

    private func setupViews() {
        // Configure scrollView
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isScrollEnabled = false
        scrollView.clipsToBounds = false
        addSubview(scrollView)
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Configure contentLabel
        contentLabel.numberOfLines = 1
        contentLabel.isHidden = false
        contentLabel.backgroundColor = .clear
        scrollView.addSubview(contentLabel)

        // Setup fade effect
        fadeLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.cgColor,
            UIColor.white.cgColor,
            UIColor.clear.cgColor,
        ]
        fadeLayer.locations = [0.0, 0.05, 0.95, 1.0]
        fadeLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        fadeLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        layer.mask = fadeLayer
    }

    private func startScrolling() {
        guard scrollTimer == nil else {
            return
        }

        // Reset to beginning
        scrollView.contentOffset = .zero

        // Create a seamless scrolling effect with a timer
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }

            // Move content
            var offset = scrollView.contentOffset
            offset.x += 1 // Adjust speed as needed, lower = slower

            // Reset position when reaching the end for continuous effect
            if offset.x >= contentLabel.frame.width {
                // Stop the current timer
                stopScrolling()

                // Wait 5 seconds before restarting the scroll from the beginning
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.startScrolling()
                }
                return
            }

            scrollView.contentOffset = offset
        }

        // Make sure the timer runs even during user interaction
        if let timer = scrollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}

// MARK: - PulseEffect

struct PulseEffect: ViewModifier {
    // MARK: Internal

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsate ? 1.1 : 1.0)
            .opacity(pulsate ? 0.1 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1)
                    .repeatForever(autoreverses: true),
                value: pulsate
            )
            .onAppear {
                pulsate = true
            }
    }

    // MARK: Private

    @State private var pulsate = false
}
