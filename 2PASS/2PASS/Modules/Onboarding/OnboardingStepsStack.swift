// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let progressTopPadding: CGFloat = 44 + 16 // default navigation bar height + padding
    static let contentTopPadding: CGFloat = 106 // below the system bar, which sits in the safe area
    static let changeProgressAnimationDuration: TimeInterval = 0.1
}

/// The shield's state above the onboarding stack, written by the shown screen's reporter.
@MainActor @Observable
final class OnboardingProgress {
    var progress: Float = 0
    var isVisible: Bool = false
}

/// Wraps one hosted screen: reads its progress preferences and writes the model, on change and on every appearance.
struct OnboardingProgressReporter<Content: View>: View {

    let progress: OnboardingProgress
    let content: Content

    // `nil` progress means the screen claims no shield (the welcome pages, the recovery flow).
    @State private var claimedProgress: Float?
    @State private var claimedVisibility: Bool?

    init(progress: OnboardingProgress, content: Content) {
        self.progress = progress
        self.content = content
    }

    var body: some View {
        content
            .onPreferenceChange(OnboardingProgressPreferenceKey.self) { value in
                claimedProgress = value
            }
            .onPreferenceChange(OnboardingProgressVisibilityPreferenceKey.self) { value in
                claimedVisibility = value
            }
            .onChange(of: claimedProgress) {
                report()
            }
            .onChange(of: claimedVisibility) {
                report()
            }
            .onAppear {
                report()
            }
    }

    private func report() {
        progress.progress = claimedProgress ?? 0
        progress.isVisible = claimedProgress != nil && (claimedVisibility ?? true)
    }
}

/// The shield above the whole stack, so it never moves with a screen.
struct OnboardingProgressOverlayView: View {

    let progress: OnboardingProgress

    init(progress: OnboardingProgress) {
        self.progress = progress
    }

    var body: some View {
        ZStack {
            if progress.isVisible {
                ProgressView(value: progress.progress)
                    .progressViewStyle(ShieldProgressStyle())
                    .animation(.default, value: progress.progress)
                    .padding(Constants.progressTopPadding)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: Constants.changeProgressAnimationDuration), value: progress.isVisible)
        .allowsHitTesting(false)
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
