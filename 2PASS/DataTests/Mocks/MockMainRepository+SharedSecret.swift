// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
@testable import Data

// `MockMainRepository.swift` imports `CryptoKit` (for `SymmetricKey`), which makes
// `SharedSecret` ambiguous between `CryptoKit.SharedSecret` and `Data.SharedSecret`. The Data
// module's name itself shadows `Foundation.Data`, so `Data.SharedSecret` doesn't disambiguate
// either. Splitting the share-secret stubs into this file — which deliberately does NOT import
// CryptoKit — lets `SharedSecret` resolve unambiguously to the Data module's type.
//
// The BackupSync test suites don't exercise either entry point, so the stubs simply throw.
// Tests that need real behavior should override these in a subclass or add stored stubs at
// that point.
extension MockMainRepository {

    func createSharedSecret(data: Foundation.Data, validForSeconds: Int, singleUse: Bool) async throws -> ShareSecretResponse {
        throw TestError.resourceNotFound("createSharedSecret not stubbed")
    }

    func fetchSharedSecret(id: String) async throws -> SharedSecret {
        throw TestError.resourceNotFound("fetchSharedSecret not stubbed")
    }
}
