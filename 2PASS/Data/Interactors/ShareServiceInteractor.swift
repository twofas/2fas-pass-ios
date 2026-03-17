// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol ShareServiceInteracting: AnyObject {
    func createSecret(data: String, validForSeconds: Int, singleUse: Bool) async throws -> ShareSecretResponse
    func fetchSecret(id: String) async throws -> SharedSecret
}

final class ShareServiceInteractor: ShareServiceInteracting {

    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }

    func createSecret(data: String, validForSeconds: Int, singleUse: Bool) async throws -> ShareSecretResponse {
        try await mainRepository.createSharedSecret(data: data, validForSeconds: validForSeconds, singleUse: singleUse)
    }

    func fetchSecret(id: String) async throws -> SharedSecret {
        try await mainRepository.fetchSharedSecret(id: id)
    }
}
