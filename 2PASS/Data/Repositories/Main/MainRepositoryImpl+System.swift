// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

extension MainRepositoryImpl {
    func copyToClipboard(_ str: String) {
        UIPasteboard.general.string = str
    }
    
    var syncHasError: Bool {
        _syncHasError
    }
    
    func setSyncHasError(_ value: Bool) {
        _syncHasError = value
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
