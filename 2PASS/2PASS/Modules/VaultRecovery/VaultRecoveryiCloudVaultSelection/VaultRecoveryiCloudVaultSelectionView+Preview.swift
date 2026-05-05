// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

final class VaultRecoveryiCloudVaultSelectionModuleInteractorPreview: VaultRecoveryiCloudVaultSelectionModuleInteracting {
    let state: State

    enum State {
        case loading
        case error
        case list
        case empty
    }

    enum LoadingError: Error {
        case generic
    }

    init(state: State) {
        self.state = state
    }

    func listVaultsToRecover() async throws -> [VaultRawData] {
        switch state {
        case .loading:
            // Suspend until the preview's enclosing task is cancelled. Mirrors the previous
            // behavior of the completion-based mock that simply never invoked its callback,
            // which left the presenter parked in `.loading` for the duration of the preview.
            try await Task.sleep(for: .seconds(.infinity))
            return []
        case .error:
            throw LoadingError.generic
        case .list:
            let device = DeviceName(deviceID: DeviceID(), deviceName: "My Device")
            let devices = try! JSONEncoder().encode([device])
            return [
                VaultRawData(
                    vaultID: VaultID(),
                    name: "Name",
                    createdAt: Date(),
                    updatedAt: Date(),
                    deviceNames: devices,
                    deviceID: DeviceID(),
                    schemaVersion: 1,
                    seedHash: "seedHash",
                    reference: "reference",
                    kdfSpec: Data(),
                    zoneID: .default
                )
            ]
        case .empty:
            return []
        }
    }

    func deleteVault(id: VaultID) async throws {
    }
}
