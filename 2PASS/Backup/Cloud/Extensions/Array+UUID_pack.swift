//
//  Array+UUID_transformation.swift
//  2PASS
//
//  Created by Zbigniew Cisiński on 20/07/2025.
//  Copyright © 2025 Two Factor Authentication Service, Inc. All rights reserved.
//

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
