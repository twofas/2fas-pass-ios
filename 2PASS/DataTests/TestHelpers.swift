// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
@testable import Data

/// Shared test helper functions for DataTests
enum DataTests {
    /// Decrypts data using the provided repository's encryption key
    static func decrypt(_ data: Data?, using mainRepository: MainRepository) -> String? {
        guard let data,
              let key = mainRepository.getKey(isPassword: true, protectionLevel: .normal),
              let decrypted = mainRepository.decrypt(data, key: key) else {
            return nil
        }
        return String(data: decrypted, encoding: .utf8)
    }
}
