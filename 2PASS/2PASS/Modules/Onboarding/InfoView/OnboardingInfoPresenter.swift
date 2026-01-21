// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

@Observable
final class OnboardingInfoPresenter {
    struct OnboardingGuideItem: Identifiable {
        let id = UUID()
        let image: Image
        let message: String
    }

    let guideItems: [OnboardingGuideItem] =  [
        .init(image: Image(systemName: "mail.and.text.magnifyingglass"), message: String(localized: .onboardingGuide1)),
        .init(image: Image(systemName: "brain.filled.head.profile"), message: String(localized: .onboardingGuide2)),
        .init(image: Image(systemName: "number.square"), message: String(localized: .onboardingGuide3)),
        .init(image: Image(systemName: "key.viewfinder"), message: String(localized: .onboardingGuide4))
    ]
}
