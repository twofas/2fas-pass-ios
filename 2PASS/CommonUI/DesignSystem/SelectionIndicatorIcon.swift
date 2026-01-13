// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public enum SelectionIndicatorState {
    case unselected
    case mixed
    case selected
}

public struct SelectionIndicatorIcon: View {
    private let state: SelectionIndicatorState

    public init(_ state: SelectionIndicatorState) {
        self.state = state
    }

    public var body: some View {
        Group {
            if let systemImageName = systemImageName {
                Image(systemName: systemImageName)
                    .font(.body)
                    .foregroundStyle(.accent)
            } else {
                Color.clear
            }
        }
        .frame(width: 22, height: 22)
    }

    private var systemImageName: String? {
        switch state {
        case .unselected:
            nil
        case .mixed:
            "checkmark.circle"
        case .selected:
            "checkmark.circle.fill"
        }
    }
}
