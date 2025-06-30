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
        .init(image: Image(systemName: "mail.and.text.magnifyingglass"), message: T.onboardingGuide1),
        .init(image: Image(systemName: "brain.filled.head.profile"), message: T.onboardingGuide2),
        .init(image: Image(systemName: "number.square"), message: T.onboardingGuide3),
        .init(image: Image(systemName: "key.viewfinder"), message: T.onboardingGuide4)
    ]
}
