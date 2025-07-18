// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public enum PasswordIconType: Hashable, Identifiable {
    public var id: Self {
        self
    }
    
    case domainIcon(String?)
    case customIcon(URL)
    case label(labelTitle: String, labelColor: UIColor?)
    
    public var value: String {
        switch self {
        case .domainIcon: "domainIcon"
        case .label: "label"
        case .customIcon: "customIcon"
        }
    }
    
    public var iconURL: URL? {
        switch self {
        case .customIcon(let url):
            return url
        case .domainIcon(let domain):
            if let domain {
                return Config.iconURL(forDomain: domain)
            }
            return nil
        default:
            return nil
        }
    }
    
    public init(iconType: String, iconDomain: String?, iconCustomURL: URL?, labelTitle: String?, labelColor: String?) {
        if iconType == "domainIcon" {
            self = .domainIcon(iconDomain)
        } else if iconType == "customIcon", let iconCustomURL {
            self = .customIcon(iconCustomURL)
        } else if iconType == "label" {
            self = .label(
                labelTitle: labelTitle ?? Config.defaultIconLabel,
                labelColor: UIColor(hexString: labelColor)
            )
        } else {
            self = Self.default
        }
    }
    
    public static var `default`: Self {
        .domainIcon(nil)
    }
    
    public static func createDefault(domain: String?) -> Self {
        .domainIcon(domain)
    }
}

extension PasswordIconType: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case type, domain, url, title, color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .type)
        switch self {
        case .domainIcon(let domain):
            try container.encode(domain, forKey: .domain)
        case .customIcon(let url):
            try container.encode(url, forKey: .url)
        case .label(let labelTitle, let labelColor):
            try container.encode(labelTitle, forKey: .title)
            try container.encode(labelColor?.hexString, forKey: .color)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "domainIcon":
            let domain = try container.decodeIfPresent(String.self, forKey: .domain)
            self = .domainIcon(domain)
        case "customIcon":
            let url = try container.decode(URL.self, forKey: .url)
            self = .customIcon(url)
        case "label":
            let title = try container.decode(String.self, forKey: .title)
            let colorHex = try container.decodeIfPresent(String.self, forKey: .color)
            self = .label(labelTitle: title, labelColor: UIColor(hexString: colorHex))
        default:
            self = .default
        }
    }
}
