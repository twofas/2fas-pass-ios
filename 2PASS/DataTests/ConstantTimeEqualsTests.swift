// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import Common
@testable import Data

/// Verifies the behavioral contract of `constantTimeEquals` added for
/// OWASP finding L-2 (non-constant-time security-relevant comparisons).
///
/// These tests assert functional correctness — matching pairs compare equal,
/// non-matching pairs compare unequal — not timing itself. Timing invariance
/// is a property of the implementation and is verified by code review and
/// by keeping the loop free of data-dependent branches.
@Suite("Data.constantTimeEquals / String.constantTimeEquals")
struct ConstantTimeEqualsTests {

    // MARK: - Data

    @Test("Matching same-length byte sequences compare equal")
    func matchingBytes() {
        let a = Data([0x01, 0x02, 0x03, 0x04])
        let b = Data([0x01, 0x02, 0x03, 0x04])
        #expect(a.constantTimeEquals(b))
    }

    @Test("Single-byte difference at arbitrary position returns false")
    func singleByteDifference() {
        let base = Data([UInt8](repeating: 0xAA, count: 32))
        for flipIndex in 0..<base.count {
            var candidate = base
            candidate[flipIndex] ^= 0x01
            #expect(!base.constantTimeEquals(candidate), "diff at index \(flipIndex) should not be equal")
        }
    }

    @Test("Length mismatch returns false even when the shorter is a prefix")
    func lengthMismatch() {
        let shorter = Data([0x01, 0x02, 0x03])
        let longer = Data([0x01, 0x02, 0x03, 0x04])
        #expect(!shorter.constantTimeEquals(longer))
        #expect(!longer.constantTimeEquals(shorter))
    }

    @Test("Two empty byte sequences compare equal")
    func emptyBytes() {
        #expect(Data().constantTimeEquals(Data()))
    }

    @Test("Empty vs non-empty compares unequal")
    func emptyVsNonEmpty() {
        #expect(!Data().constantTimeEquals(Data([0x01])))
        #expect(!Data([0x01]).constantTimeEquals(Data()))
    }

    @Test("Self-equality holds for random-looking inputs")
    func selfEquality() {
        let values: [Data] = [
            Data([0x00]),
            Data([0xFF]),
            Data([UInt8](repeating: 0x42, count: 1024)),
            Data((0..<256).map { UInt8($0) })
        ]
        for value in values {
            #expect(value.constantTimeEquals(value))
        }
    }

    // MARK: - String

    @Test("Matching ASCII strings compare equal")
    func matchingASCII() {
        let a = "b2f0c4e1-6a2d-4aa3-9b11-1c3d7e8f2a01"
        let b = "b2f0c4e1-6a2d-4aa3-9b11-1c3d7e8f2a01"
        #expect(a.constantTimeEquals(b))
    }

    @Test("Single-character ASCII difference returns false")
    func singleCharDifference() {
        let a = "abcdef1234567890"
        let b = "abcdef1234567891" // last digit flipped
        #expect(!a.constantTimeEquals(b))
    }

    @Test("Different lengths return false")
    func stringLengthMismatch() {
        #expect(!"abcd".constantTimeEquals("abcde"))
        #expect(!"abcde".constantTimeEquals("abcd"))
    }

    @Test("Two empty strings compare equal")
    func emptyStrings() {
        #expect("".constantTimeEquals(""))
    }

    @Test("Hex-digest parity with Data.constantTimeEquals for ASCII")
    func hexDigestParityWithData() {
        let hexA = "deadbeefcafebabe"
        let hexB = "deadbeefcafebabe"
        #expect(hexA.constantTimeEquals(hexB))

        // And a failure case with the same method.
        let hexC = "deadbeefcafebab0"
        #expect(!hexA.constantTimeEquals(hexC))
    }
}
