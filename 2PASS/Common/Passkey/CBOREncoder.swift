// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Minimal CBOR encoder supporting types needed for WebAuthn attestation objects.
public enum CBOREncoder {

    public enum Value {
        case unsignedInt(UInt64)
        case negativeInt(Int64)
        case byteString(Data)
        case textString(String)
        case map([(Value, Value)])
        case boolean(Bool)
    }

    public static func encode(_ value: Value) -> Data {
        var data = Data()
        encodeValue(value, into: &data)
        return data
    }

    // MARK: - Private

    private static func encodeValue(_ value: Value, into data: inout Data) {
        switch value {
        case .unsignedInt(let n):
            encodeHead(majorType: 0, value: n, into: &data)

        case .negativeInt(let n):
            // CBOR negative: -1 - n → encode as major type 1 with value (-1 - n)
            let encoded = UInt64(-1 - n)
            encodeHead(majorType: 1, value: encoded, into: &data)

        case .byteString(let bytes):
            encodeHead(majorType: 2, value: UInt64(bytes.count), into: &data)
            data.append(bytes)

        case .textString(let string):
            let utf8 = Data(string.utf8)
            encodeHead(majorType: 3, value: UInt64(utf8.count), into: &data)
            data.append(utf8)

        case .map(let pairs):
            encodeHead(majorType: 5, value: UInt64(pairs.count), into: &data)
            for (key, val) in pairs {
                encodeValue(key, into: &data)
                encodeValue(val, into: &data)
            }

        case .boolean(let flag):
            data.append(flag ? 0xF5 : 0xF4)
        }
    }

    private static func encodeHead(majorType: UInt8, value: UInt64, into data: inout Data) {
        let mt = majorType << 5
        switch value {
        case 0...23:
            data.append(mt | UInt8(value))
        case 24...0xFF:
            data.append(mt | 24)
            data.append(UInt8(value))
        case 0x100...0xFFFF:
            data.append(mt | 25)
            var big = UInt16(value).bigEndian
            data.append(Data(bytes: &big, count: 2))
        case 0x10000...0xFFFF_FFFF:
            data.append(mt | 26)
            var big = UInt32(value).bigEndian
            data.append(Data(bytes: &big, count: 4))
        default:
            data.append(mt | 27)
            var big = value.bigEndian
            data.append(Data(bytes: &big, count: 8))
        }
    }
}
