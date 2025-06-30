// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

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
    
    func listVaultsToRecover(completion: @escaping (Result<[Common.VaultRawData], any Error>) -> Void) {
        switch state {
        case .loading:
            break
        case .error:
            completion(.failure(LoadingError.generic))
        case .list:
            let device = DeviceName(deviceID: DeviceID(), deviceName: "My Device")
            let devices = try! JSONEncoder().encode([device])
            completion(.success([
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
            ]))
        case .empty:
            completion(.success([]))
        }
    }
}
