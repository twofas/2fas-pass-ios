// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct ConnectLabelStyle: LabelStyle {
    
    let iconColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.s) {
            configuration.icon
                .foregroundStyle(iconColor)
            configuration.title
                .foregroundStyle(.neutral950)
                .font(.title2Emphasized)
        }
    }
}
