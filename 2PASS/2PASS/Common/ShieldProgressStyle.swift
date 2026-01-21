// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let shieldFillWidth = 32.0
}

public struct ShieldProgressStyle: ProgressViewStyle {
        
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Image(.shieldBorder)
            Image(.shieldFill)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(width: (configuration.fractionCompleted ?? 0) * Constants.shieldFillWidth)
                }
        }
    }
}
