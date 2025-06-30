// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let shakeAnimationSteps: [CGFloat] = [0, -2, 2, -1, 1]
    static let shakeAnimationMultiplier = 8.0
    static let shakeStepAnimationDuration = 0.1
}

extension View {
    
    public func shakeAnimation(trigger: Bool) -> some View {
        phaseAnimator(Constants.shakeAnimationSteps, trigger: trigger, content: { view, value in
            view.offset(x: trigger ? value * Constants.shakeAnimationMultiplier : 0)
        }, animation: { value in
            .spring(duration: Constants.shakeStepAnimationDuration)
        })
    }
}
