// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol ShareLinkImportModuleInteracting: AnyObject {
    func fetchSharedSecret(id: String) async throws -> String
    func decryptImportRequest(
        encryptedData: String,
        components: ShareLinkComponents,
        password: String?
    ) throws -> any ItemDataChangeRequest
}

final class ShareLinkImportModuleInteractor: ShareLinkImportModuleInteracting {

    private let shareLinkInteractor: ShareLinkInteracting

    init(shareLinkInteractor: ShareLinkInteracting) {
        self.shareLinkInteractor = shareLinkInteractor
    }

    func fetchSharedSecret(id: String) async throws -> String {
        try await shareLinkInteractor.fetchSharedSecret(id: id)
    }

    func decryptImportRequest(
        encryptedData: String,
        components: ShareLinkComponents,
        password: String?
    ) throws -> any ItemDataChangeRequest {
        let plaintext = try shareLinkInteractor.decryptSharedSecret(
            encryptedData: encryptedData,
            components: components,
            password: password
        )
        return try shareLinkInteractor.makeImportRequest(from: plaintext)
    }
}
