// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol ShareLinkImportModuleInteracting: AnyObject {
    func fetchSharedSecret(id: String) async throws -> String
    func decryptSharedSecret(
        encryptedData: String,
        components: ShareLinkComponents,
        password: String?
    ) throws -> any ItemDataChangeRequest
}

final class ShareLinkImportModuleInteractor: ShareLinkImportModuleInteracting {

    private let shareInteractor: ShareLinkInteracting

    init(shareInteractor: ShareLinkInteracting) {
        self.shareInteractor = shareInteractor
    }

    func fetchSharedSecret(id: String) async throws -> String {
        try await shareInteractor.fetchSharedSecret(id: id)
    }

    func decryptSharedSecret(
        encryptedData: String,
        components: ShareLinkComponents,
        password: String?
    ) throws -> any ItemDataChangeRequest {
        try shareInteractor.decryptSharedSecret(
            encryptedData: encryptedData,
            components: components,
            password: password
        )
    }
}
