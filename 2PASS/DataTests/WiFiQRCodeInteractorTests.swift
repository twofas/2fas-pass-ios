// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Common
@testable import Data

@Suite("WiFi QR Code Interactor")
struct WiFiQRCodeInteractorTests {

    private let interactor = WiFiQRCodeInteractor()

    @Test("Make payload with escaping and hidden field")
    func makePayloadWithEscaping() {
        let data = WiFiQRCodeData(
            ssid: #"Cafe;WiFi:Main\Lobby"#,
            password: #"pa;ss:word\123"#,
            securityType: .wpa2,
            hidden: true
        )

        let payload = interactor.makeWiFiQRCodePayload(from: data)

        #expect(payload == #"WIFI:T:WPA;S:Cafe\;WiFi\:Main\\Lobby;P:pa\;ss\:word\\123;H:true;;"#)
    }

    @Test("Detect valid payload")
    func detectValidPayload() {
        let payload = #"WIFI:T:WEP;S:Guest\;Network;P:abc\:123\;xyz;H:true;;"#

        let result = interactor.detectWiFiQRCodeData(from: payload)

        #expect(result?.ssid == "Guest;Network")
        #expect(result?.password == "abc:123;xyz")
        #expect(result?.securityType == .wep)
        #expect(result?.hidden == true)
    }

    @Test("Reject payload without SSID")
    func rejectPayloadWithoutSSID() {
        let payload = "WIFI:T:WPA;P:password;H:true;;"
        let result = interactor.detectWiFiQRCodeData(from: payload)

        #expect(result == nil)
    }
}
