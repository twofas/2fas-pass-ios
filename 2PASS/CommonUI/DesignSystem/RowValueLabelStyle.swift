// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension LabelStyle where Self == RowValueLabelStyle {
    
    public static var rowValue: RowValueLabelStyle {
        .init()
    }
}

public struct RowValueLabelStyle: LabelStyle {
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xs) {
            configuration.icon
            configuration.title
        }
    }
}
