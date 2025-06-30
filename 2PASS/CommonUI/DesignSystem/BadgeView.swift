// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct BadgeView: View {
    
    let value: Int
    
    public init(value: Int) {
        self.value = value
    }
    
    public var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 20, height: 20)
            .overlay {
                Text(value, format: .number)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
    }
}
