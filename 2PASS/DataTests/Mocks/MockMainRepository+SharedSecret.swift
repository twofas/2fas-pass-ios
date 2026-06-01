// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
@testable import Data

extension MockMainRepository {

    func createSharedSecret(data: Foundation.Data, validForSeconds: Int, singleUse: Bool) async throws -> ShareSecretResponse {
        throw TestError.resourceNotFound("createSharedSecret not stubbed")
    }

    func fetchSharedSecret(id: String) async throws -> SharedSecret {
        throw TestError.resourceNotFound("fetchSharedSecret not stubbed")
    }
}
