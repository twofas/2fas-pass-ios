// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public extension WiFiContent.SecurityType {
    var cxfValue: String {
        switch self {
        case .none: "unsecured"
        case .wep: "wep"
        case .wpa: "wpa-personal"
        case .wpa2: "wpa2-personal"
        case .wpa3: "wpa3-personal"
        }
    }

    init(cxfValue: String?) {
        guard let normalized = cxfValue?.nonBlankTrimmedOrNil?.lowercased() else {
            self = .wpa2
            return
        }

        switch normalized {
        case "none", "nopass", "unsecured":
            self = .none
        case "wep":
            self = .wep
        case "wpa", "wpa-personal":
            self = .wpa
        case "wpa2", "wpa2-personal":
            self = .wpa2
        case "wpa3", "wpa3-personal":
            self = .wpa3
        default:
            if normalized.hasPrefix("wpa3") {
                self = .wpa3
            } else if normalized.hasPrefix("wpa2") {
                self = .wpa2
            } else if normalized.hasPrefix("wpa") {
                self = .wpa
            } else {
                self = .wpa2
            }
        }
    }
}
