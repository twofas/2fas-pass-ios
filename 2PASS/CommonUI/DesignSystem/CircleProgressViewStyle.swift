// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension ProgressViewStyle where Self == CircleProgressViewStyle {
    public static var circle: CircleProgressViewStyle {
        .init()
    }
}

private struct Constants {
    static let size = 64.0
    static let lineWidth = 4.0
}

public struct CircleProgressViewStyle: ProgressViewStyle {
    
    public func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .stroke(Color.brand200, lineWidth: Constants.lineWidth)
                
                Circle()
                    .trim(from: 0, to: configuration.fractionCompleted ?? 0)
                    .stroke(Color.brand500, lineWidth: Constants.lineWidth)
                    .animation(.default, value: configuration.fractionCompleted ?? 0)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: Constants.size, height: Constants.size)
             
            configuration.label?
                .font(.footnote)
                .foregroundStyle(.neutral500)
        }
    }
}

#Preview {
    Group {
        ProgressView(value: 0.1)
        ProgressView(value: 0.5)
        ProgressView(value: 1)
    }
    .progressViewStyle(.circle)
    .frame(width: 100, height: 100)
}
