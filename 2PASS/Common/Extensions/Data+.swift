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

    // MARK: - Base64URL (RFC 4648 §5)

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(contentsOf: repeatElement("=", count: 4 - remainder))
        }
        self.init(base64Encoded: base64)
    }

    // MARK: - Constant-time equality

    /// Compares two byte sequences in time that depends only on their length,
    /// not on their content. Use for security-relevant equality (MAC tags,
    /// session-key proofs, password-derived hashes, encryption-reference
    /// plaintexts) to avoid leaking the position of the first differing byte
    /// through a measurable timing side-channel.
    ///
    /// A length mismatch short-circuits — the lengths of our comparands are
    /// either fixed (UUID strings, 16-byte salts) or derived from public
    /// HMAC/hash sizes, so leaking "are they the same length" is not sensitive.
    func constantTimeEquals(_ other: Data) -> Bool {
        guard count == other.count else { return false }
        var accumulator: UInt8 = 0
        withUnsafeBytes { (lhs: UnsafeRawBufferPointer) in
            other.withUnsafeBytes { (rhs: UnsafeRawBufferPointer) in
                for i in 0..<count {
                    accumulator |= lhs[i] ^ rhs[i]
                }
            }
        }
        return accumulator == 0
    }
}

public extension String {
    /// Constant-time equality over the UTF-8 byte representation of two
    /// strings. Callers are expected to normalize ahead of time (both sides
    /// in the same form) — e.g., both ASCII hex digests, both `.exportString()`
    /// UUID outputs. For general Unicode input, normalize via
    /// `decomposedStringWithCompatibilityMapping` before calling.
    ///
    /// See `Data.constantTimeEquals(_:)` for the timing-attack rationale.
    func constantTimeEquals(_ other: String) -> Bool {
        guard let a = data(using: .utf8), let b = other.data(using: .utf8) else {
            return false
        }
        return a.constantTimeEquals(b)
    }
}
