// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Testing
import Common
@testable import Data

/// Pins the bytes Argon2 hashes when the master key is derived. These bytes cannot change: the
/// master key is stored nowhere that could verify it afterwards, so a different input means every
/// existing vault becomes unreadable, with no way back.
///
/// Two layers on purpose. The differential layer re-implements the historical expression as an
/// oracle, so any rewrite of `argon2Password` has to agree with it for every input in the table.
/// The anchors are hand-computed hex, so a mistake in the oracle itself does not pass unnoticed —
/// both layers would have to be wrong in the same way.
@Suite struct Argon2PasswordTests {
    let seed = Data([0x00, 0x01, 0x02, 0x03])

    /// The shape `MainRepositoryImpl.generateMasterKey` used before the input was built directly:
    /// hex-encode both halves, concatenate, parse back.
    func historicalOracle(seed: Data, masterPassword: String) -> Data? {
        let hexPassword = Data(masterPassword.decomposedStringWithCompatibilityMapping.utf8).hexEncodedString()
        return Data(hexString: "\(seed.hexEncodedString())\(hexPassword)")
    }

    @Test(arguments: [
        "password",
        "",
        "żółć gęślą jaźń",
        "\u{00E9}",                     // é, precomposed
        "e\u{0301}",                    // e + combining acute — NFKD makes these identical
        "\u{FB01}",                     // ﬁ ligature: decomposed by NFKD, left alone by NFD/NFC
        "\u{FF21}",                     // Ａ full width: same discriminator
        "\u{1F510}\u{1F511}",           // 🔐🔑
        String(repeating: "correct horse battery staple ", count: 40),
    ])
    func matchesTheHistoricalInput(password: String) throws {
        let produced = argon2Password(seed: seed, masterPassword: password)
        let expected = try #require(historicalOracle(seed: seed, masterPassword: password))
        #expect(produced == expected, "input bytes changed for \(password.debugDescription)")
    }

    @Test func anchorsPinTheBytesByHand() {
        // seed ‖ utf8(NFKD(password)), in lowercase hex.
        let cases: [(password: String, expected: String)] = [
            ("abc", "00010203" + "616263"),
            ("", "00010203"),
            ("\u{00E9}", "00010203" + "65cc81"),   // é → "e" + U+0301
            ("\u{FB01}", "00010203" + "6669"),     // ﬁ → "fi": NFKD only, NFD/NFC keep the ligature
            ("\u{FF21}", "00010203" + "41"),       // Ａ → "A": NFKD only
        ]
        for c in cases {
            let produced = argon2Password(seed: seed, masterPassword: c.password)
            #expect(produced.hexEncodedString() == c.expected, "anchor broke for \(c.password.debugDescription)")
        }
    }

    @Test func compositionFormDoesNotMatter() {
        // The whole point of normalising: the same password typed on two keyboards derives one key.
        let precomposed = argon2Password(seed: seed, masterPassword: "cafe\u{0301}")
        let decomposed = argon2Password(seed: seed, masterPassword: "caf\u{00E9}")
        #expect(precomposed == decomposed)
    }

    @Test func theSeedComesFirstAndTheEmptyCasesDegradeCleanly() {
        #expect(argon2Password(seed: seed, masterPassword: "") == seed)
        #expect(argon2Password(seed: Data(), masterPassword: "ab") == Data([0x61, 0x62]))
        #expect(argon2Password(seed: Data(), masterPassword: "").isEmpty)
        // Order, not just contents: swapping the halves would still contain the same bytes.
        #expect(argon2Password(seed: Data([0xAA]), masterPassword: "\u{0062}") == Data([0xAA, 0x62]))
    }
}
