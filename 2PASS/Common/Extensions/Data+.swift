// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0 ..< len {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
    
    func hexEncodedString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
    
    func hexEncodedStringFrom4Bits() -> String {
        map { String(format: "%01hhx", $0) }.joined()
    }
    
    func splitInto4BitGroups() -> [UInt8] {
        var result: [UInt8] = []
        
        for byte in self {
            result.append(byte >> 4)
            result.append(byte & 0x0F)
        }
        
        return result
    }
    
    func getBits(startBit: Int, numberOfBits: Int) -> UInt16 {
        let startByte = startBit / 8
        let startBitInByte = startBit % 8
        let endByte = (startBit + numberOfBits - 1) / 8
        
        var result: UInt16 = 0
        
        for i in startByte...endByte {
            let byte = self[i]
            let validBits = Swift.min(8 - startBitInByte, numberOfBits - (i - startByte) * 8)
            let mask = UInt8(0xFF >> (8 - validBits))
            let shiftedByte = (byte >> startBitInByte) & mask
            
            result = (result << validBits) | UInt16(shiftedByte)
        }
        
        return result
    }
    
    func toBinaryString() -> String {
        return self.map { byte in
            let binary = String(byte, radix: 2)
            return String(repeating: "0", count: 8 - binary.count) + binary
        }.joined()
    }
}
