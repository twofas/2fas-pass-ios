// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit

extension View {

    func clearSelectionOnLeavingApp<Value>(_ selection: Binding<Value?>) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            selection.wrappedValue = nil
        }
    }
}
