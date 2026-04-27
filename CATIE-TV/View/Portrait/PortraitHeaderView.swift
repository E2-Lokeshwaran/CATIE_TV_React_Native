//
//  PortraitHeaderView.swift
//  CATIE-TV
//
//  Created by Harish on 30/04/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import SwiftUI

// MARK: - PortraitHeaderView

struct PortraitHeaderView: View {
    // MARK: Internal

    /// The time to display
    let headerTime: String

    /// The date to display
    let headerDate: String

    /// The temperature to display
    let temperature: String

    /// The location to display
    let location: String

    /// The weather icon to display
    let weatherIcon: UIImage?

    /// The site logo to display
    let siteLogo: UIImage?

    /// Theme for styling
    let theme: PortraitTheme

    // MARK: - Body

    var body: some View {
        GeometryReader { _ in
            HStack {
                // Weather icon and temperature
                weatherHeaderContent

                Spacer()

                // Center logo
                logoContent

                Spacer()

                // Time and date
                timeAndDateContent
            }
            .offset(y: 55)
        }

        .padding(.vertical, 10)
        .padding(.horizontal, 70)
        .background(theme.headerBackground)
        .cornerRadius(25, corners: [.bottomLeft, .bottomRight])
        .shadow(color: theme.headerShadow, radius: 5, x: 0, y: 2)
        .frame(width: UIScreen.main.bounds.height, height: 145)
        .accessibilityIdentifier("portraitHeaderView")
    }

    // MARK: Private

    // MARK: - Component Views

    /// Weather header content
    private var weatherHeaderContent: some View {
        HStack(spacing: 8) {
            if let weatherIcon {
                Image(uiImage: weatherIcon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(theme.primaryText)
                    .accessibilityIdentifier("weatherIcon")
            } else {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(theme.primaryText)
                    .font(.system(size: 36))
                    .accessibilityIdentifier("defaultWeatherIcon")
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(temperature)
                    .font(.custom("Poppins-Bold", size: 24))
                    .foregroundColor(theme.primaryText)
                    .accessibilityIdentifier("temperatureText")

                Text(location)
                    .font(.custom("Poppins-Regular", size: 24))
                    .foregroundColor(theme.primaryText)
                    .accessibilityIdentifier("locationText")
            }
            .accessibilityIdentifier("weatherTextContainer")
        }
        .padding(.leading, 15)
        .accessibilityIdentifier("weatherSection")
    }

    /// Logo content
    private var logoContent: some View {
        Group {
            if let siteLogo {
                Image(uiImage: siteLogo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250, maxHeight: 70)
                    .accessibilityIdentifier("siteLogo")
            } else {
                Image("SS")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250, maxHeight: 70)
                    .accessibilityIdentifier("defaultSiteLogo")
            }
        }
        .accessibilityIdentifier("logoSection")
    }

    /// Time and date content
    private var timeAndDateContent: some View {
        HStack(spacing: 8) {
            // Time and date
            VStack(alignment: .trailing, spacing: 0) {
                Text(headerTime)
                    .font(.custom("Poppins-Medium", size: 36))
                Text(headerDate)
                    .font(.custom("Poppins-Regular", size: 18))
            }
            .foregroundColor(theme.primaryText)
            .accessibilityIdentifier("timeDateContainer")

            Image("StatusSolutionIcon")
                .resizable()
                .scaledToFit()
                .frame(height: 36)
                .accessibilityIdentifier("statusSolutionIcon")
        }
        .padding(.trailing, 15)
        .accessibilityIdentifier("timeAndDateSection")
        .offset(y: -8)
    }
}

// MARK: - Preview

#if DEBUG
    struct PortraitHeaderView_Previews: PreviewProvider {
        static var previews: some View {
            let theme = PortraitTheme(colorScheme: .light)

            PortraitHeaderView(
                headerTime: "12:45",
                headerDate: "April 30, 2025",
                temperature: "72°",
                location: "San Francisco",
                weatherIcon: nil,
                siteLogo: nil,
                theme: theme
            )
            .previewLayout(.fixed(width: 1080, height: 150))
        }
    }
#endif
