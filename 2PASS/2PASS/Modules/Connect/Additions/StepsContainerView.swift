// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let initialFullFrameColor = Color(red: 163/255, green: 163/255, blue: 163/255)
    static let showTitleAnimationDuration: Double = 0.3
    static let drawFullFrameAnimationDuration = 0.7
    static let fullFrameDimmedAnimationDuration = 0.5
    static let fullFrameCornerRadius = 24.0
    static let fullFrameLineWidth = 1.0
    static let dimmedAnimationDelay = Duration.milliseconds(700)
    static let stepAppearVerticalOffset: CGFloat = -30
}

struct StepsContainerView<Content>: View where Content: View {
    
    let title: Text
    let content: Content
    
    init(title: Text, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    private var appearContent = true
        
    @State
    private var dimmedBorder = false
    
    var body: some View {
        VStack(spacing: Spacing.s) {
            title
                .font(.footnote)
                .foregroundStyle(.neutral500)
                .padding(.bottom, Spacing.xs)
                .opacity(appearContent ? 1 : 0)
                .animation(.easeInOut(duration: Constants.showTitleAnimationDuration), value: appearContent)
            
            content
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.s)
        .overlay {
            fullFrame
        }
        .onAppear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dimmedBorder = appearContent
            }
        }
        .onChange(of: appearContent) { oldValue, newValue in
            if newValue {
                Task {
                    try await Task.sleep(for: Constants.dimmedAnimationDelay)
                    dimmedBorder = true
                }
            } else {
                dimmedBorder = false
            }
        }
    }
    
    func appearAnimationTrigger(_ value: Bool) -> Self {
        var instance = self
        instance.appearContent = value
        return instance
    }
    
    private var fullFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.fullFrameCornerRadius)
                .trim(from: 0.25, to: 0.25 + (appearContent ? 1 : 0) * 0.5)
                .stroke(
                    dimmedBorder ? .neutral100 : Constants.initialFullFrameColor,
                    lineWidth: Constants.fullFrameLineWidth
                )
            
            RoundedRectangle(cornerRadius: Constants.fullFrameCornerRadius)
                .trim(from: 0.25, to: 0.25 + (appearContent ? 1 : 0) * 0.5)
                .stroke(
                    dimmedBorder ? .neutral100 : Constants.initialFullFrameColor,
                    lineWidth: Constants.fullFrameLineWidth
                )
                .scaleEffect(x: -1, y: 1)
        }
        .animation(.smooth(duration: Constants.drawFullFrameAnimationDuration), value: appearContent)
        .animation(.easeInOut(duration: Constants.fullFrameDimmedAnimationDuration), value: dimmedBorder)
        .scaleEffect(x: 1, y: -1)
    }
}

extension View {
    
    func stepAppearAnimation(
        _ appear: Bool,
        delay: TimeInterval,
        offset: CGFloat = Constants.stepAppearVerticalOffset
    ) -> some View {
        self.offset(y: appear ? 0 : offset)
        .animation(.smooth.delay(delay), value: appear)
        .opacity(appear ? 1 : 0)
        .animation(.easeInOut.delay(delay), value: appear)
    }
}

#Preview {
    @State @Previewable var show = false
    
    VStack {
        StepsContainerView(title: Text("2FAS Pass Title")) {
            StepView(title: Text("Title"), subtitle: Text("Subtitle"))
                .stepAppearAnimation(show, delay: 0.3)
            
            StepView(title: Text("Title 2"), subtitle: Text("Subtitle 2"))
                .stepAppearAnimation(show, delay: 0.6)
        }
        .appearAnimationTrigger(show)
        .padding()
        
        Button("Show") {
            show.toggle()
        }
    }
}
