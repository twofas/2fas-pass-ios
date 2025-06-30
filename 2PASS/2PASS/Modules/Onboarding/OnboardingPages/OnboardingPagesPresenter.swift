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
            title: T.onboardingWelcome1Title,
            subtitle: T.onboardingWelcome1Description,
            features: [
                .init(
                    icon: .sfSymbol("network.badge.shield.half.filled"),
                    title: T.onboardingWelcome1Feature1
                ),
                .init(
                    icon: .sfSymbol("eye.slash.circle"),
                    title: T.onboardingWelcome1Feature2
                ),
                .init(
                    icon: .sfSymbol("person.crop.circle.badge.xmark"),
                    title: T.onboardingWelcome1Feature3
                )
            ]
        ),
        .init(
            animationName: "ios-onboarding-02",
            title: T.onboardingWelcome2Title,
            subtitle: T.onboardingWelcome2Description,
            features: [
                .init(
                    icon: .sfSymbol("infinity.circle"),
                    title: T.onboardingWelcome2Feature1
                ),
                .init(
                    icon: .sfSymbol("square.and.arrow.up"),
                    title: T.onboardingWelcome2Feature2
                ),
                .init(
                    icon: .sfSymbol("lock.slash.fill"),
                    title: T.onboardingWelcome2Feature3
                )
            ]
        ),
        .init(
            animationName: "ios-onboarding-03",
            title: T.onboardingWelcome3Title,
            subtitle: T.onboardingWelcome3Description,
            features: [
                .init(
                    icon: .sfSymbol("iphone.radiowaves.left.and.right"),
                    title: T.onboardingWelcome3Feature1
                ),
                .init(
                    icon: .sfSymbol("lock.shield"),
                    title: T.onboardingWelcome3Feature2
                ),
                .init(
                    icon: .asset("Maze"),
                    title: T.onboardingWelcome3Feature3
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
