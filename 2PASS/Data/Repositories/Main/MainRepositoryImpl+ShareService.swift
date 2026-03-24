// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

extension MainRepositoryImpl {

    func createSharedSecret(data: Data, validForSeconds: Int, singleUse: Bool) async throws -> ShareSecretResponse {
        let request = ShareSecretRequest(data: data, validForSeconds: validForSeconds, singleUse: singleUse)
        return try await twoFASShareServiceSession.createSecret(request: request)
    }

    func fetchSharedSecret(id: String) async throws -> SharedSecret {
        try await twoFASShareServiceSession.fetchSecret(id: id)
    }
}
