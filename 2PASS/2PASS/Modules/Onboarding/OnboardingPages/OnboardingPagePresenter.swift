// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct OnboardingPage: Identifiable {
    struct Feature: Identifiable {
        enum Icon {
            case sfSymbol(String)
            case asset(String)
        }

        let id = UUID()
        let icon: Icon
        let title: String
    }
    let id = UUID()
    let animationName: String
    let title: String
    let subtitle: String
    let features: [Feature]
    
}

@Observable
final class OnboardingPagePresenter {
    let onboardingPage: OnboardingPage
    
    init(onboardingPage: OnboardingPage) {
        self.onboardingPage = onboardingPage
    }
}
