// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct KDFSpec: Codable, Hashable {
    public enum KDFType: String, Codable {
        case argon2i = "argon2i"
        case argon2d = "argon2d"
        case argon2id = "argon2id"
    }
    public let kdfType: KDFType
    public let hashLength: Int
    public let memoryMB: Int
    public let iterations: Int
    public let parallelism: Int
    
    public static var `default`: Self {
        KDFSpec(
            kdfType: Config.kdfSpec.algorithm,
            hashLength: Config.kdfSpec.hashLength,
            memoryMB: Config.kdfSpec.memoryMB,
            iterations: Config.kdfSpec.iterations,
            parallelism: Config.kdfSpec.parallelism
        )
    }
    
    public init(
        kdfType: KDFType,
        hashLength: Int,
        memoryMB: Int,
        iterations: Int,
        parallelism: Int
    ) {
        self.kdfType = kdfType
        self.hashLength = hashLength
        self.memoryMB = memoryMB
        self.iterations = iterations
        self.parallelism = parallelism
    }
}
