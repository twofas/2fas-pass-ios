// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public extension KDFSpec {
    init?(_ spec: ExchangeVault.ExchangeEncryption.ExchangeKDFSpec) {
        self = .init(
            kdfType: {
                if let type = spec.type {
                    return KDFType(rawValue: type) ?? Config.kdfSpec.algorithm
                }
                return Config.kdfSpec.algorithm
            }(),
            hashLength: spec.hashLength ?? Config.kdfSpec.hashLength,
            memoryMB: spec.memoryMb ?? Config.kdfSpec.memoryMB,
            iterations: spec.iterations ?? Config.kdfSpec.iterations,
            parallelism: spec.parallelism ?? Config.kdfSpec.parallelism
        )
    }
}
