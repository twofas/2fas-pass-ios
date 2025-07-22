// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension Data {
    func toUUIDArray() -> [UUID]? {
        let uuidSize = 16
        guard self.count % uuidSize == 0 else { return nil }
        return self.withUnsafeBytes { rawBuffer in
            var uuids: [UUID] = []
            for i in stride(from: 0, to: self.count, by: uuidSize) {
                guard let ptr = rawBuffer.baseAddress?.advanced(by: i) else {
                    return nil
                }
                let uuid = ptr.withMemoryRebound(to: uuid_t.self, capacity: 1) {
                    UUID(uuid: $0.pointee)
                }
                uuids.append(uuid)
            }
            return uuids
        }
    }
}
