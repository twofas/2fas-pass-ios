// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Observation

@Observable
final class BulkProtectionLevelPresenter {
    
    private(set) var totalSelectedCount: Int
    private let flowController: BulkProtectionLevelFlowControlling
    private let countsByLevel: [ItemProtectionLevel: Int]
    private let initialUniformLevel: ItemProtectionLevel?
    
    private(set) var pendingProtectionLevel: ItemProtectionLevel?
    
    @ObservationIgnored
    var onChange: (() -> Void)?
    
    init(flowController: BulkProtectionLevelFlowControlling, countsByLevel: [ItemProtectionLevel: Int]) {
        self.flowController = flowController
        self.countsByLevel = countsByLevel
        let totalSelectedCount = countsByLevel.values.reduce(0, +)
        self.totalSelectedCount = totalSelectedCount
        
        if totalSelectedCount > 0, countsByLevel.count == 1 {
            self.initialUniformLevel = countsByLevel.keys.first
        } else {
            self.initialUniformLevel = nil
        }
    }
    
    var hasPendingChanges: Bool {
        guard let pendingProtectionLevel else { return false }
        return pendingProtectionLevel != initialUniformLevel
    }

    func selectProtectionLevel(_ level: ItemProtectionLevel) {
        pendingProtectionLevel = level
        onChange?()
    }

    func handleCancel() {
        flowController.handleCancel()
    }

    func handleSave(source: UIBarButtonItem) {
        guard let pendingProtectionLevel else { return }
        
        Task { @MainActor in
            if await flowController.toConfirmChangeAlert(selectedCount: totalSelectedCount,source: source) {
                flowController.handleConfirmChange(pendingProtectionLevel)
            }
        }
    }
    
    func count(for level: ItemProtectionLevel) -> Int {
        countsByLevel[level] ?? 0
    }
    
    func indicatorState(for level: ItemProtectionLevel) -> SelectionIndicatorState {
        if let pendingProtectionLevel {
            return pendingProtectionLevel == level ? .selected : .unselected
        }
        let count = count(for: level)
        guard count > 0 else { return .unselected }
        return count == totalSelectedCount ? .selected : .mixed
    }
}
