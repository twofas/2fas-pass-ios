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
        baseUrl: String,
        normalizedURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        completion: @escaping (Result<BackupIndex, WebDAVRecoveryInteractorError>) -> Void
    )
    func resetConfiguration()
}

final class VaultRecoveryWebDAVModuleInteractor {
    private let webDAVRecoveryInteractor: WebDAVRecoveryInteracting
    private let uriInteractor: URIInteracting
    
    init(webDAVRecoveryInteractor: WebDAVRecoveryInteracting, uriInteractor: URIInteracting) {
        self.webDAVRecoveryInteractor = webDAVRecoveryInteractor
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
    
    func resetConfiguration() {
        webDAVRecoveryInteractor.resetConfiguration()
    }
    
    func recover(
        baseUrl: String,
        normalizedURL: URL,
        allowTLSOff: Bool,
        login: String?,
        password: String?,
        completion: @escaping (Result<BackupIndex, WebDAVRecoveryInteractorError>) -> Void
    ) {
        webDAVRecoveryInteractor
            .recover(
                baseURL: baseUrl,
                normalizedURL: normalizedURL,
                allowTLSOff: allowTLSOff,
                login: login,
                password: password,
                completion: completion
            )
    }
}

