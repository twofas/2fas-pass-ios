// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let progressTopPadding: CGFloat = 44 + 16 // default navigation bar height + padding
    static let contentTopPadding: CGFloat = 44 + 106 // default navigation bar height + padding
    static let changeProgressAnimationDuration: TimeInterval = 0.1
}

struct OnboardingStepsStack<Root>: View where Root: View {
    
    let root: () -> Root
            
    @State private var isProgessVisible = true
    
    var body: some View {
        SlideNavigationStack(root: root)
            .toolbar(.hidden)
            .overlayPreferenceValue(OnboardingProgressPreferenceKey.self, alignment: .top) { progress in
                ZStack {
                    if isProgessVisible {
                        ProgressView(value: progress)
                            .progressViewStyle(ShieldProgressStyle())
                            .animation(.default, value: progress)
                            .padding(Constants.progressTopPadding)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: Constants.changeProgressAnimationDuration), value: isProgessVisible)
            }
            .onPreferenceChange(OnboardingProgressVisibilityPreferenceKey.self) { isVisible in
                isProgessVisible = isVisible ?? true
            }
    }
}

struct OnboardingProgressPreferenceKey: PreferenceKey {
    static let defaultValue: Float = 0
    
    static func reduce(value: inout Float, nextValue: () -> Float) {
        value = max(value, nextValue())
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
