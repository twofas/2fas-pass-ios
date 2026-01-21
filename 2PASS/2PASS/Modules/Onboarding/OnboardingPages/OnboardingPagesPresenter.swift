// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

enum OnboardingPagesDestination: Identifiable {
    case getStarted
    case recover
    
    var id: String {
        switch self {
        case .getStarted: return "get-started"
        case .recover: return "recover"
        }
    }
}

@Observable
final class OnboardingPagesPresenter {
    
    var destination: OnboardingPagesDestination?

    var pages: [OnboardingPage] = [
        .init(
            animationName: "ios-onboarding-01",
            title: String(localized: .onboardingWelcome1Title),
            subtitle: String(localized: .onboardingWelcome1Description),
            features: [
                .init(
                    icon: .sfSymbol("network.badge.shield.half.filled"),
                    title: String(localized: .onboardingWelcome1Feature1)
                ),
                .init(
                    icon: .sfSymbol("eye.slash.circle"),
                    title: String(localized: .onboardingWelcome1Feature2)
                ),
                .init(
                    icon: .sfSymbol("person.crop.circle.badge.xmark"),
                    title: String(localized: .onboardingWelcome1Feature3)
                )
            ]
        ),
        .init(
            animationName: "ios-onboarding-02",
            title: String(localized: .onboardingWelcome2Title),
            subtitle: String(localized: .onboardingWelcome2Description),
            features: [
                .init(
                    icon: .sfSymbol("infinity.circle"),
                    title: String(localized: .onboardingWelcome2Feature1)
                ),
                .init(
                    icon: .sfSymbol("square.and.arrow.up"),
                    title: String(localized: .onboardingWelcome2Feature2)
                ),
                .init(
                    icon: .sfSymbol("lock.slash.fill"),
                    title: String(localized: .onboardingWelcome2Feature3)
                )
            ]
        ),
        .init(
            animationName: "ios-onboarding-03",
            title: String(localized: .onboardingWelcome3Title),
            subtitle: String(localized: .onboardingWelcome3Description),
            features: [
                .init(
                    icon: .sfSymbol("iphone.radiowaves.left.and.right"),
                    title: String(localized: .onboardingWelcome3Feature1)
                ),
                .init(
                    icon: .sfSymbol("lock.shield"),
                    title: String(localized: .onboardingWelcome3Feature2)
                ),
                .init(
                    icon: .asset("Maze"),
                    title: String(localized: .onboardingWelcome3Feature3)
                )
            ]
        )
    ]
    
    func onGetStartedTap() {
        destination = .getStarted
    }
    
    func onRecoverTap() {
        destination = .recover
    }
}
