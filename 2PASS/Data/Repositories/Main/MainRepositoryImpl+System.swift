// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

extension MainRepositoryImpl {
    func copyToClipboard(_ str: String, isSecure: Bool) {
        if isSecure {
            UIPasteboard.general.setItems(
                [[UIPasteboard.typeAutomatic: str]],
                options: [
                    .expirationDate: Date().addingTimeInterval(Config.Clipboard.secureValueLifetime)
                ]
            )
        } else {
            UIPasteboard.general.string = str
        }
    }

    func positiveFeedback() {
        feedbackGenerator.notificationOccurred(.success)
    }
    
    func negativeFeedback() {
        feedbackGenerator.notificationOccurred(.error)
    }
    
    func warningFeedback() {
        feedbackGenerator.notificationOccurred(.warning)
    }
}
