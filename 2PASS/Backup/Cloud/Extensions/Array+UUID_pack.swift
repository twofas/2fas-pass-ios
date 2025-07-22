// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension Array where Element == UUID {
    func toData() -> Data {
        var data = Data()
        for uuid in self {
            var uuidBytes = uuid.uuid
            Swift.withUnsafeBytes(of: &uuidBytes) { buffer in
                data.append(buffer.bindMemory(to: UInt8.self))
            }
        }
        return data
    }
}
