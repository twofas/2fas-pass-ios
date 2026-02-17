// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol WiFiQRCodeInteracting: AnyObject {
    func makeWiFiQRCodePayload(from data: WiFiQRCodeData) -> String
    func detectWiFiQRCodeData(from payload: String) -> WiFiQRCodeData?
}

final class WiFiQRCodeInteractor {}

extension WiFiQRCodeInteractor: WiFiQRCodeInteracting {
    
    func makeWiFiQRCodePayload(from data: WiFiQRCodeData) -> String {
        let passwordValue = (data.password ?? "").escapedForWiFiQRCode
        let ssidValue = data.ssid.escapedForWiFiQRCode
        let hiddenField = data.hidden ? "H:true;" : ""
        return "WIFI:T:\(data.securityType.qrCodeValue);S:\(ssidValue);P:\(passwordValue);\(hiddenField);"
    }

    func detectWiFiQRCodeData(from payload: String) -> WiFiQRCodeData? {
        guard payload.uppercased().hasPrefix("WIFI:") else {
            return nil
        }

        let content = String(payload.dropFirst(5))
        let fields = content.splitByUnescaped(separator: ";")
        var parsedValues = [String: String]()

        for field in fields where field.isEmpty == false {
            guard let separatorIndex = field.firstIndexOfUnescaped(separator: ":") else {
                continue
            }

            let rawKey = String(field[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = String(field[field.index(after: separatorIndex)...])
            guard rawKey.isEmpty == false else {
                continue
            }
            parsedValues[rawKey.uppercased()] = rawValue.unescapedFromWiFiQRCode
        }

        guard let ssid = parsedValues["S"], ssid.isEmpty == false else {
            return nil
        }

        let securityType: WiFiContent.SecurityType = {
            switch parsedValues["T"]?.uppercased() {
            case "NOPASS", "NONE":
                .none
            case "WEP":
                .wep
            case "WPA":
                .wpa
            case "WPA2":
                .wpa2
            case "WPA3":
                .wpa3
            default:
                .wpa2
            }
        }()

        let hidden: Bool = {
            switch parsedValues["H"]?.lowercased() {
            case "true", "1":
                true
            default:
                false
            }
        }()

        return .init(
            ssid: ssid,
            password: parsedValues["P"],
            securityType: securityType,
            hidden: hidden
        )
    }
}

private extension WiFiContent.SecurityType {
    var qrCodeValue: String {
        switch self {
        case .none:
            "nopass"
        case .wep:
            "WEP"
        case .wpa, .wpa2, .wpa3:
            "WPA"
        }
    }
}

private extension String {
    var escapedForWiFiQRCode: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ":", with: "\\:")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    var unescapedFromWiFiQRCode: String {
        var result = ""
        var isEscaping = false

        for character in self {
            if isEscaping {
                result.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            result.append(character)
        }

        if isEscaping {
            result.append("\\")
        }

        return result
    }

    func splitByUnescaped(separator: Character) -> [String] {
        var parts = [String]()
        var current = ""
        var isEscaping = false

        for character in self {
            if isEscaping {
                current.append(character)
                isEscaping = false
                continue
            }

            if character == "\\" {
                current.append(character)
                isEscaping = true
                continue
            }

            if character == separator {
                parts.append(current)
                current = ""
                continue
            }

            current.append(character)
        }

        parts.append(current)
        return parts
    }

    func firstIndexOfUnescaped(separator: Character) -> String.Index? {
        var isEscaping = false

        for index in indices {
            let character = self[index]

            if isEscaping {
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            if character == separator {
                return index
            }
        }

        return nil
    }
}
