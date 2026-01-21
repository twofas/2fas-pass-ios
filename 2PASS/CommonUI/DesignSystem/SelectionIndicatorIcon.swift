// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public enum SelectionIndicatorState {
    case unselected
    case mixed
    case selected
}

public struct SelectionIndicatorIcon: View {

    public enum UnselectedStyle {
        case hidden
        case circle
    }

    private let state: SelectionIndicatorState
    private var unselectedStyle: UnselectedStyle = .hidden

    public init(_ state: SelectionIndicatorState) {
        self.state = state
    }

    public func unselectedStyle(_ style: UnselectedStyle) -> Self {
        var copy = self
        copy.unselectedStyle = style
        return copy
    }

    public var body: some View {
        Group {
            switch state {
            case .unselected:
                switch unselectedStyle {
                case .hidden:
                    Color.clear
                case .circle:
                    Circle()
                        .stroke(Color.neutral500)
                }
            case .mixed:
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .font(.body)
                    .foregroundStyle(.accent)
            case .selected:
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .font(.body)
                    .foregroundStyle(.accent)
            }
        }
        .frame(width: 20, height: 20)
    }
}
