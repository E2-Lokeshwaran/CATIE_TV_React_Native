//
//  PortraitCarouselView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import SwiftUI

// MARK: - PortraitCarouselView

/// A carousel view component that can display images with optional audio indicators
/// in both normal and full-screen modes
struct PortraitCarouselView: View {
    // MARK: - Properties

    /// The current image to display in the carousel
    var currentImage: UIImage?

    /// Whether the current carousel item has audio associated with it
    var hasAudio: Bool = false

    /// Whether audio narration is currently playing
    var isNarrationPlaying: Bool = false

    /// Whether to display in full screen mode or not
    var uiType: Int16 = 4

    /// The theme for styling (optional)
    var theme: PortraitTheme?

    /// Current color scheme from the environment
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Body

    var body: some View {
        Group {
            if uiType == 4 {
                fullCarouselView
                    .accessibilityIdentifier("fullScreenCarouselView")
            } else if uiType == 6 {
                VStack {
                    centerCarouselView
                        .accessibilityIdentifier("centerCarouselView")
                        .padding(.top, 5)
                    Spacer()
                }
            } else {
                standardCarouselView
                    .accessibilityIdentifier("standardCarouselView")
            }
        }
        .accessibilityIdentifier("portraitCarouselView")
    }

    // MARK: - Standard Carousel

    /// Standard sized carousel view
    private var standardCarouselView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 30
            let height = geometry.size.height - 20
            VStack(spacing: 0) {
                ZStack {
                    carouselImageContent(width: width, height: height)
                        .accessibilityIdentifier("carouselImageContent")
                    carouselAudioContent(width: width, height: height)
                        .accessibilityIdentifier("carouselAudioContent")
                }
                .frame(width: width, height: height)

                Spacer()
            }
            .padding(.leading, 15)
            .padding(.top, 10)
        }
    }
    private func carouselImageContent(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let carouselImage = currentImage, !isDefaultCarouselImage(uiImage: currentImage) {
                smartStretchImage(carouselImage, width: width, height: height, cornerRadius: 15)
                    .shadow(color: theme?.cardShadow ?? Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
                    .accessibilityIdentifier("carouselCustomImage")
            } else {
                Image("DummyCarousalSquare")
                    .resizable()
                    .frame(width: width, height: height)
                    .cornerRadius(15)
                    .shadow(color: theme?.cardShadow ?? Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
                    .accessibilityIdentifier("carouselDefaultImage")
            }
        }
    }

    private func carouselAudioContent(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if hasAudio,
               isNarrationPlaying,
               !isDefaultCarouselImage(uiImage: currentImage)
            {
                VStack {
                    HStack {
                        Spacer()

                        // Audio icon with blur effect
                        ZStack {
                            // Use BlurView for a proper blur effect instead of solid color
                            BlurView(style: .dark)
                                .frame(width: 60, height: 60)
                                .cornerRadius(20)
                                .accessibilityIdentifier("audioIconBlurBackground")

                            // Icon
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .accessibilityIdentifier("audioIcon")
                        }
                        .padding(15)
                        .accessibilityIdentifier("audioIconContainer")
                    }

                    Spacer()
                }
                .frame(width: width, height: height) // Match parent size
                .accessibilityIdentifier("standardAudioOverlay")
            }
        }
    }

    // MARK: - Full Screen Carousel

    /// Full-screen carousel view
    private var fullCarouselView: some View {
        let horizontalPadding: CGFloat = 80  // Safe area padding on each side
        let totalWidth: CGFloat = 1080 - (horizontalPadding * 2)  // Width within safe area = 920

        let totalScreenHeight: CGFloat = UIScreen.main.bounds.width // Total available height (portrait) - 1920
        let topSpacing: CGFloat = 145  // Match header height to stick to it
        let bottomSpacing: CGFloat = 145  // Space for footer

        // Calculate available height between header and footer
        let totalHeight = totalScreenHeight - topSpacing - bottomSpacing  // 1920 - 145 - 145 = 1630

        return VStack(spacing: 0) {
            Spacer()
                .frame(height: topSpacing)

            ZStack {
                fullCarouselImageContent(width: totalWidth, height: totalHeight)
                    .accessibilityIdentifier("fullCarouselImageContent")

                // Only show audio icon when needed
                fullCarouselAudioContent(width: totalWidth, height: totalHeight)
                    .accessibilityIdentifier("fullCarouselAudioContent")
            }
            .frame(width: totalWidth, height: totalHeight)

            Spacer()
                .frame(height: bottomSpacing)
        }
        .frame(width: 1080, height: totalScreenHeight)
        .padding(.horizontal, horizontalPadding)
    }

    private var centerCarouselView: some View {
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let horizontalSpacing: CGFloat = 90

            let topSpacing: CGFloat = 150
            let bottomSpacing: CGFloat = 110

            // Calculate frame within safe area with spacing
            let safeWidth = geometry.size.width - safeArea.leading - safeArea.trailing
            let safeHeight = geometry.size.height - safeArea.top - safeArea.bottom

            let width = safeWidth - (horizontalSpacing * 2)
            let height = safeHeight - topSpacing - bottomSpacing

            // Center the carousel within the safe area with equal spacing
            let xPosition = safeArea.leading + (safeWidth / 2)
            let yPosition = safeArea.top + topSpacing + (height / 2)

            ZStack {
                fullCarouselImageContent(width: width, height: height)
                    .accessibilityIdentifier("centerCarouselImageContent")

                // Add audio icon overlay for Type 6
                centerCarouselAudioContent(width: width, height: height)
                    .accessibilityIdentifier("centerCarouselAudioContent")
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black)
            )
            .position(x: xPosition, y: yPosition)
        }
    }

    private func fullCarouselImageContent(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let carouselImage = currentImage, !isDefaultCarouselImage(uiImage: currentImage) {
                // UI Type 4: Fill the exact space end-to-end
                Image(uiImage: carouselImage)
                    .resizable()
                    .frame(width: width, height: height)
                    .clipped()
                    .accessibilityIdentifier("fullCarouselCustomImage")
            } else {
                // Placeholder image
                Image("DummyCarousalPortrait")
                    .resizable()
                    .frame(width: width, height: height)
                    .accessibilityIdentifier("fullCarouselDefaultImage")
            }
        }
        .frame(width: width, height: height)
    }

    private func fullCarouselAudioContent(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if hasAudio,
               isNarrationPlaying,
               !isDefaultCarouselImage(uiImage: currentImage)
            {
                VStack {
                    HStack {
                        Spacer()

                        // Audio icon with blur effect
                        ZStack {
                            // Use BlurView for a proper blur effect instead of solid color
                            BlurView(style: .dark)
                                .frame(width: 60, height: 60)
                                .cornerRadius(20)
                                .accessibilityIdentifier("fullAudioIconBlurBackground")

                            // Icon
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .accessibilityIdentifier("fullAudioIcon")
                        }
                        .padding(15)
                        .accessibilityIdentifier("fullAudioIconContainer")
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 50)

                    Spacer()
                }
                .frame(width: width, height: height)
                .accessibilityIdentifier("fullAudioOverlay")
            }
        }
    }

    private func centerCarouselAudioContent(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if hasAudio,
               isNarrationPlaying,
               !isDefaultCarouselImage(uiImage: currentImage)
            {
                VStack {
                    HStack {
                        Spacer()

                        // Audio icon with blur effect
                        ZStack {
                            // Use BlurView for a proper blur effect instead of solid color
                            BlurView(style: .dark)
                                .frame(width: 60, height: 60)
                                .cornerRadius(20)
                                .accessibilityIdentifier("centerAudioIconBlurBackground")

                            // Icon
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .accessibilityIdentifier("centerAudioIcon")
                        }
                        .padding(15)
                        .accessibilityIdentifier("centerAudioIconContainer")
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 15)

                    Spacer()
                }
                .frame(width: width, height: height)
                .accessibilityIdentifier("centerAudioOverlay")
            }
        }
    }

    // MARK: - Helper Methods

    /// Renders image to fill the entire frame with fixed dimensions
    /// All images will fill the frame exactly like the default image
    private func smartStretchImage(_ image: UIImage, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        return Image(uiImage: image)
            .resizable()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Checks if the provided image is the default placeholder
    private func isDefaultCarouselImage(uiImage: UIImage?) -> Bool {
        // If no image, consider it default
        guard let image = uiImage else {
            return true
        }

        // Only check if this is the default image by comparing with DummyCarousal
        if let cgImage = image.cgImage,
           let defaultImage = UIImage(named: "DummyCarousal")?.cgImage
        {
            // Compare the images by their CGImage backing
            return cgImage == defaultImage
        }

        // If we can't determine, assume it's not the default image
        return false
    }
}

// MARK: - Preview

#if DEBUG
    struct CarouselView_Previews: PreviewProvider {
        static var previews: some View {
            VStack {
                // Standard carousel
                PortraitCarouselView(
                    currentImage: UIImage(named: "DummyCarousalSquare"),
                    hasAudio: true,
                    isNarrationPlaying: true
                )

                Spacer()

                // Example with audio playing
                Text("Full screen carousel would take the entire screen")
                    .padding()
            }
        }
    }
#endif
