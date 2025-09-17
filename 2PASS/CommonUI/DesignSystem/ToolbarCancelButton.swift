// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct ToolbarCancelButton: View {
    let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        if #available(iOS 26, *) {
            Button(symbol: Image(systemName: "xmark")) {
                action()
            }
        } else {
            Button(T.commonCancel.localizedKey) {
                action()
            }
        }
    }
}
