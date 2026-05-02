// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Backup

protocol VaultRecoveryWebDAVModuleInteracting: AnyObject {

    func isSecureURL(_ url: URL) -> Bool
    func normalizeURL(_ url: String) -> URL?

    func recover(
        baseURL: String,
        normalizedURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?
    ) async throws(VaultRecoveryWebDAVError) -> BackupIndex
}

final class VaultRecoveryWebDAVModuleInteractor {
    private let recoveryInteractor: BackupSyncRecoveryInteracting
    private let uriInteractor: URIInteracting

    init(
        recoveryInteractor: BackupSyncRecoveryInteracting,
        uriInteractor: URIInteracting
    ) {
        self.recoveryInteractor = recoveryInteractor
        self.uriInteractor = uriInteractor
    }
}

extension VaultRecoveryWebDAVModuleInteractor: VaultRecoveryWebDAVModuleInteracting {

    func isSecureURL(_ url: URL) -> Bool {
        uriInteractor.isSecureURL(url)
    }

    func normalizeURL(_ url: String) -> URL? {
        uriInteractor.normalizeURL(url, options: .trailingSlash)
    }

    func recover(
        baseURL: String,
        normalizedURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?
    ) async throws(VaultRecoveryWebDAVError) -> BackupIndex {
        let config = BackupWebDAVConfig(
            baseURL: baseURL,
            normalizedURL: normalizedURL,
            allowTLSOff: allowTLSOff,
            login: login,
            password: password
        )

        do {
            return try await recoveryInteractor.fetchIndex(config)
        } catch {
            // Single `catch` + inner `switch` is the form Swift's typed-throws exhaustiveness
            // checker accepts. Multiple `catch BackupIndexFetchError.X` clauses look exhaustive
            // by inspection but the compiler doesn't recognize them that way — and the case
            // names `.transport`/`.indexIsDamaged` collide with `VaultRecoveryWebDAVError`,
            // making leading-dot inference unreliable too. Switching over the bound `error`
            // sidesteps both issues.
            switch error {
            case .transport(let transportError):
                // 404 here means "no index yet at this URL" — distinct from the vault-fetch
                // 404 in `VaultRecoverySelectWebDAVIndexModuleInteractor` ("vault disappeared
                // from server").
                if case .notFound = transportError {
                    throw VaultRecoveryWebDAVError.indexNotFound
                }
                throw VaultRecoveryWebDAVError.transport(transportError)
            case .indexIsDamaged:
                throw VaultRecoveryWebDAVError.indexIsDamaged
            }
        }
    }

}
