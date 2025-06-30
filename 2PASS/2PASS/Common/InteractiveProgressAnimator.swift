// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

@Observable
final class InteractiveProgressAnimator {
    
    private struct AnimationContext {
        var startAnimationValue: Double
        var targetAnimationValue: Double
        var startAnimation: Date
    }
    
    let animationDuration: TimeInterval
    let cancelAnimationDuration: TimeInterval
    
    private(set) var isGenerating = false
    private(set) var progress: CGFloat = 0
    
    var isFinished: Bool {
        progress == 1
    }
    
    private var displayLink: CADisplayLink?
    private var animationContext: AnimationContext?
    
    init(animationDuration: TimeInterval, cancelAnimationDuration: TimeInterval) {
        self.animationDuration = animationDuration
        self.cancelAnimationDuration = cancelAnimationDuration
    }
    
    func onPressingChanged(to status: Bool) {
        guard isFinished == false else { return }

        if status {
            animationContext = AnimationContext(
                startAnimationValue: progress,
                targetAnimationValue: 1,
                startAnimation: Date()
            )
            
            displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
            displayLink?.add(to: .main, forMode: .default)
            
        } else if progress > 0 {
            isGenerating = false
            animationContext = AnimationContext(
                startAnimationValue: progress,
                targetAnimationValue: 0,
                startAnimation: Date()
            )
            
        } else {
            isGenerating = false
            displayLink?.invalidate()
            displayLink = nil
        }
        
        isGenerating = status
    }
    
    @objc func updateFrame() {
        guard let context = animationContext else { return }
        
        let fullDuration: Double = (context.targetAnimationValue == 1) ? animationDuration : cancelAnimationDuration
        let duration = (context.targetAnimationValue - context.startAnimationValue) * fullDuration
        let newProgess = context.startAnimationValue + abs(context.targetAnimationValue - context.startAnimationValue) * -Double(context.startAnimation.timeIntervalSinceNow) / duration

        progress = newProgess
        
        if newProgess > 1 || newProgess < 0 {
            isGenerating = false
            displayLink?.invalidate()
            displayLink = nil
            
            if newProgess > 1 {
                progress = 1
            } else {
                progress = 0
            }
        }
    }
}
