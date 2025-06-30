// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension ButtonStyle where Self == ProgressButtonStyle {
    
    public static func progress(duration: TimeInterval, trigger: Bool = true) -> ProgressButtonStyle {
        ProgressButtonStyle(duration: duration, trigger: trigger)
    }
}

public struct ProgressButtonStyle: ButtonStyle {
    
    let duration: TimeInterval
    let trigger: Bool
    
    init(duration: TimeInterval, trigger: Bool) {
        self.duration = duration
        self.trigger = trigger
    }
    
    @State
    private var isAnimating: Bool = false
    
    @Environment(\.controlSize)
    private var controlSize
    
    public func makeBody(configuration: Configuration) -> some View {
        Color.brand100
            .frame(height: ButtonMetrics(controlSize: controlSize).height)
            .overlay(alignment: .leading) {
                Color.brand200
                    .frame(width: isAnimating ? nil : 0)
                    .animation(.linear(duration: duration), value: isAnimating)
            }
            .overlay {
                configuration.label
                    .font(ButtonMetrics(controlSize: controlSize).font)
                    .foregroundStyle(.brand500)
            }
            .clipShape(RoundedRectangle(cornerRadius: ButtonMetrics(controlSize: controlSize).cornerRadius))
            .onAppear {
                isAnimating = trigger
            }
            .onChange(of: trigger) { oldValue, newValue in
                isAnimating = newValue
            }
    }
}

#Preview {
    Button("Close") {
        
    }
    .buttonStyle(ProgressButtonStyle(duration: 3, trigger: true))
    .padding()
    .controlSize(.large)
}
