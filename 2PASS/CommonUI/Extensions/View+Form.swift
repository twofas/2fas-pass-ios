// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension View {
    
    func formFieldChanged(_ changed: Bool) -> some View {
        listRowBackground(changed ? Color.brand50 : nil)
    }
}
