// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct NavigationBarBack<TrailingButton: View>: View {
    private let backAction: Callback
    private let title: String?
    private let trailingButton: TrailingButton
        
    init(
        backAction: @escaping Callback,
        title: String? = nil,
        @ViewBuilder trailingButton: () -> TrailingButton = { EmptyView()}
    ) {
        self.backAction = backAction
        self.title = title
        self.trailingButton = trailingButton()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.m) {
                BackButton(backAction: backAction)

                if let title {
                    Text(verbatim: title)
                        .font(.headline)
                        .lineLimit(2)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHeading(.h1)
                } else {
                    Spacer()
                }
                
                trailingButton
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.s)
    }
}
