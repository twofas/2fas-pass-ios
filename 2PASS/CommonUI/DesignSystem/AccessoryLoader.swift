// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension View {
    
    public func accessoryLoader(_ isLoading: Bool) -> some View {
        HStack {
            self
            
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .controlSize(.regular)
            }
        }
        .animation(.default, value: isLoading)
    }
}
