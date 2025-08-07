// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

@Observable
final class ChangeProtectionLevelPresenter {
    private let flowController: ChangeProtectionLevelFlowControlling
    
    var currentProtectionLevel: ItemProtectionLevel {
        didSet {
            didSelectProtectionLevel(value: currentProtectionLevel)
        }
    }
    
    init(flowController: ChangeProtectionLevelFlowControlling, currentProtectionLevel: ItemProtectionLevel) {
        self.flowController = flowController
        self.currentProtectionLevel = currentProtectionLevel
    }
    
    private func didSelectProtectionLevel(value: ItemProtectionLevel) {
        flowController.toSelectedProtectionLevel(value: value)
        flowController.close()
    }
}
