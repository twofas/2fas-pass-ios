// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let progressTopPadding: CGFloat = 16 // below the safe area, which holds the bar where there is one
    static let contentTopPadding: CGFloat = 106 // below the system bar, which sits in the safe area
    static let changeProgressAnimationDuration: TimeInterval = 0.1
}

/// The shield's state above the onboarding stack, written by the shown screen's reporter.
@MainActor @Observable
final class OnboardingProgress {
    var progress: Float = 0

    // A screen that claims a progress has the shield; it enters and leaves with that screen.
    var isClaimed: Bool = false

    // Within a claiming screen the shield can hide in place (the Master Password's focused field).
    var isVisible: Bool = true
}

/// Wraps one hosted screen: reads its progress preferences and writes the model, on change and on every appearance.
struct OnboardingProgressReporter<Content: View>: View {

    let progress: OnboardingProgress
    let content: Content

    // `nil` progress means the screen claims no shield (the welcome pages, the recovery flow).
    @State private var claimedProgress: Float?
    @State private var claimedVisibility: Bool?

    // The first appearance reports through the preferences, whose initial delivery may follow it;
    // a reappearance after a pop reports what was claimed.
    @State private var hasAppeared = false

    init(progress: OnboardingProgress, content: Content) {
        self.progress = progress
        self.content = content
    }

    var body: some View {
        content
            .onPreferenceChange(OnboardingProgressPreferenceKey.self) { value in
                claimedProgress = value
                report()
            }
            .onPreferenceChange(OnboardingProgressVisibilityPreferenceKey.self) { value in
                claimedVisibility = value
                report()
            }
            .onAppear {
                if hasAppeared {
                    report()
                }
                hasAppeared = true
            }
            .flowOverlayClaim(claimedProgress != nil)
    }

    private func report() {
        progress.progress = claimedProgress ?? 0
        progress.isClaimed = claimedProgress != nil
        progress.isVisible = claimedVisibility ?? true
    }
}

/// The shield above the whole stack: the stack's slide carries it in and out with the screen that
/// claims it (`flowOverlayClaim`), and it stays in place while the steps slide beneath it.
struct OnboardingProgressOverlayView: View {

    let progress: OnboardingProgress

    init(progress: OnboardingProgress) {
        self.progress = progress
    }

    var body: some View {
        ZStack {
            if progress.isClaimed {
                shield
                    .transition(.identity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private var shield: some View {
        ZStack {
            if progress.isVisible {
                ProgressView(value: progress.progress)
                    .progressViewStyle(ShieldProgressStyle())
                    .animation(.default, value: progress.progress)
                    .padding(Constants.progressTopPadding)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Constants.changeProgressAnimationDuration), value: progress.isVisible)
    }
}

struct OnboardingProgressPreferenceKey: PreferenceKey {
    static let defaultValue: Float? = nil

    static func reduce(value: inout Float?, nextValue: () -> Float?) {
        switch (value, nextValue()) {
        case (let current?, let next?):
            value = max(current, next)
        case (nil, let next?):
            value = next
        case (_, nil):
            break
        }
    }
}

struct OnboardingProgressVisibilityPreferenceKey: PreferenceKey {
    static let defaultValue: Bool? = nil

    static func reduce(value: inout Bool?, nextValue: () -> Bool?) {
        value = nextValue() ?? value
    }
}

extension View {

    func onboardingStepProgressVisibility(_ visible: Bool) -> some View {
        preference(key: OnboardingProgressVisibilityPreferenceKey.self, value: visible)
    }

    func onboardingStepProgress(_ progress: Float) -> some View {
        preference(key: OnboardingProgressPreferenceKey.self, value: progress)
    }

    func onboardingStepTopPadding(adjust: (CGFloat) -> CGFloat = { $0 }) -> some View {
        padding(.top, adjust(Constants.contentTopPadding))
    }
}
