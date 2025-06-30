// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public enum PasswordEncryptedIconType: Hashable, Identifiable {
    public var id: Self {
        self
    }

    case domainIcon(Data?)
    case customIcon(Data)
    case label(labelTitle: Data, labelColor: UIColor?)
    
    public var value: String {
        switch self {
        case .domainIcon: "domainIcon"
        case .label: "label"
        case .customIcon: "customIcon"
        }
    }

    public init(iconType: String, iconDomain: Data?, iconCustomURL: Data?, labelTitle: Data?, labelColor: UIColor?) {
        if iconType == "domainIcon" {
            self = .domainIcon(iconDomain)
        } else if iconType == "customIcon", let iconCustomURL {
            self = .customIcon(iconCustomURL)
        } else if let labelTitle, iconType == "label" {
            self = .label(labelTitle: labelTitle, labelColor: labelColor)
        } else {
            self = .label(labelTitle: Data(), labelColor: nil)
        }
    }
}

extension PasswordEncryptedIconType: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case iconFile
        case iconDomain
        case iconCustomURL
        case labelTitle
        case labelColor
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .domainIcon(let domain):
            try container.encode("domainIcon", forKey: .type)
            try container.encodeIfPresent(domain, forKey: .iconDomain)
            
        case .customIcon(let url):
            try container.encode("customIcon", forKey: .type)
            try container.encode(url, forKey: .iconCustomURL)
            
        case .label(let labelTitle, let labelColor):
            try container.encode("label", forKey: .type)
            try container.encode(labelTitle, forKey: .labelTitle)
            try container.encodeIfPresent(labelColor?.cgColor.components, forKey: .labelColor)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "domainIcon":
            let domain = try container.decodeIfPresent(Data.self, forKey: .iconDomain)
            self = .domainIcon(domain)
            
        case "label":
            let labelTitle = try container.decode(Data.self, forKey: .labelTitle)
            let components = try container.decodeIfPresent([CGFloat].self, forKey: .labelColor)
            let color: UIColor? = {
                guard let components,
                      let red = components[safe: 0],
                      let green = components[safe: 1],
                      let blue = components[safe: 2],
                      let alpha = components[safe: 3] else {
                    return nil
                }
                return UIColor(red: red, green: green, blue: blue, alpha: alpha)
            }()
            self = .label(labelTitle: labelTitle, labelColor: color)
        
        case "customIcon":
            let url = try container.decode(Data.self, forKey: .iconCustomURL)
            self = .customIcon(url)
            
        default:
            self = .label(labelTitle: Data(), labelColor: .clear)
        }
    }
}
