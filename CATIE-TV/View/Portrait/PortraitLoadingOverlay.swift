//
//  PortraitLoadingOverlay.swift
//  CATIE-TV
//
//  Created by Harish on 09/05/25.
//  Copyright © 2025 statusSolutions. All rights reserved.
//

import SwiftUI

// MARK: - PortraitLoadingOverlay

struct PortraitLoadingOverlay: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
            )
            .accessibilityIdentifier("portraitLoadingOverlay")
    }
}

#if DEBUG
    struct PortraitLoadingOverlay_Previews: PreviewProvider {
        static var previews: some View {
            PortraitLoadingOverlay()
                .previewLayout(.fixed(width: 1080, height: 1920))
        }
    }
#endif
