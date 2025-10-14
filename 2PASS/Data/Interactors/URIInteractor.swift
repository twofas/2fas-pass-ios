// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol URIInteracting: AnyObject {
    func isSecureURL(_ url: URL) -> Bool
    func normalize(_ str: String) -> String?
    func normalizeURL(_ str: String) -> URL?
    func normalizeURL(_ str: String, options: URINormalizeOptions) -> URL?
    func extractDomain(from str: String) -> String?
    func isMatch(_ str: String, to uri: String, rule: PasswordURI.Match) -> Bool
}

public struct URINormalizeOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let doNotRemoveWWW = URINormalizeOptions(rawValue: 1 << 0)
    public static let trailingSlash = URINormalizeOptions(rawValue: 2 << 0)
}

final class URIInteractor {

    private static let ending: Regex = try! Regex(##"\/(\?|\#|\?\#|\#\?)*$"##)

    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension URIInteractor: URIInteracting {
    
    func isSecureURL(_ url: URL) -> Bool {
        url.scheme == "https"
    }
    
    func extractDomain(from str: String) -> String? {
        guard str.isEmpty == false, let normalized = normalize(str) else {
            return nil
        }
        
        return URLComponents(string: normalized)?.host
    }
    
    // MARK: Normalize
    
    func normalize(_ str: String) -> String? {
        normalize(str, options: [])
    }
    
    func normalizeURL(_ str: String) -> URL? {
        guard let normalized = normalize(str, options: []) else {
            return nil
        }
        return URL(string: normalized)
    }
    
    func normalizeURL(_ str: String, options: URINormalizeOptions) -> URL? {
        guard let normalized = normalize(str, options: options) else {
            return nil
        }
        return URL(string: normalized)
    }
    
    func normalize(_ str: String, options: URINormalizeOptions) -> String? {
        if let cached = mainRepository.uriCacheGet(originalUri: str) {
            return cached
        }
        
        var string = str.trim()
        guard !string.isEmpty else { return nil }
        if !(string.lowercased().hasPrefix("https://") || string.lowercased().hasPrefix("http://")) {
            if shouldAddTheScheme(string) {
                string = "https://" + string
            }
        }
        guard let idn = URL(string: string)?.absoluteString,
              var components = NSURLComponents(string: idn, encodingInvalidCharacters: false)
        else { return nil }
        
        let queryItems = components.queryItems?.filter({ !listTrackerParams.contains($0.name) })
        components.queryItems = queryItems
        components.scheme = components.scheme?.lowercased()
        
        if let host = components.host {
            let parts = host.split(separator: ".")
            if parts.count > 2 {
                if options.contains(.doNotRemoveWWW) == false, parts.first?.lowercased() == "www" {
                    components.host = parts.dropFirst().joined(separator: ".")
                }
            }
        }
        
        components.user = nil
        components.password = nil
        components.host = components.host?.lowercased()
        
        if let scheme = components.scheme, let port = components.port {
            if (scheme == "http" && port == 80) || (scheme == "https" && port == 443) {
                components.port = nil
            }
        }
        
        components.path = components.path?.removingPercentEncoding
        
        let ranges = components.string?.ranges(of: URIInteractor.ending).reversed()
        if let ranges, !ranges.isEmpty, var str = components.string {
            for r in ranges {
                str.replaceSubrange(r, with: "")
            }
            guard let newComp = NSURLComponents(string: str, encodingInvalidCharacters: false) else { return nil }
            components = newComp
        }
        
        if var path = components.percentEncodedPath {
            for (index, char) in path.enumerated() {
                if char == "%" {
                    if index + 2 < path.count {
                        let startIndex = path.index(path.startIndex, offsetBy: index)
                        let endIndex = path.index(path.startIndex, offsetBy: index + 2)
                        let value = String(path[index...(index + 2)]).uppercased()
                        path.replaceSubrange(startIndex...endIndex, with: value)
                    }
                }
            }
            components.percentEncodedPath = path
        }
        
        if options.contains(.trailingSlash) {
            if let path = components.path {
                if path.last != "/" {
                    components.path = path + "/"
                }
            } else {
                components.path = "/"
            }
        }
        
        let value = components.url?.absoluteString
        
        if let value {
            mainRepository.uriCacheSet(originalUri: str, parsedUri: value)
        }
        
        return value
    }
    
    private func shouldAddTheScheme(_ str: String) -> Bool {
        let string = "https://" + str
        guard let idn = URL(string: string)?.absoluteString,
              let components = NSURLComponents(string: idn, encodingInvalidCharacters: false)
        else { return false }
        guard let host = components.host else {
            return false
        }
        if isValidIPAddress(host) {
            return true
        }
        let splitted = host.split(separator: ".")
        guard splitted.count > 1, let last = splitted.last?.uppercased().trim() else {
            return false
        }
        return tldList.firstIndex(where: { $0 == last }) != nil
    }
    
    func isMatch(_ input: String, to uri: String, rule: PasswordURI.Match) -> Bool {
        switch rule {
        case .domain:
            isMatchByDomainRule(input, to: uri)
        case .host:
            isMatchByHostRule(input, to: uri)
        case .startsWith:
            isMatchByPrefixRule(input, to: uri)
        case .exact:
            isMatchByExactRule(input, to: uri)
        }
    }
    
    private func isMatchByDomainRule(_ input: String, to uri: String) -> Bool {
        let normalizedInput = normalize(input) ?? ""
        let normalizedUri = normalize(uri) ?? ""
        
        guard let inputURLComponents = URLComponents(string: normalizedInput) else {
            return false
        }
    
        guard let uriURLComponents = URLComponents(string: normalizedUri) else {
            return false
        }
        
        let lhs = removeSubdomain(fromHost: inputURLComponents.host ?? "")
        let rhs = removeSubdomain(fromHost: uriURLComponents.host ?? "")
        
        return lhs == rhs
    }
    
    private func isMatchByHostRule(_ input: String, to uri: String) -> Bool {
        let normalizedInput = normalize(input) ?? ""
        let normalizedUri = normalize(uri) ?? ""
        
        guard let inputURLComponents = URLComponents(string: normalizedInput) else {
            return false
        }
    
        guard let uriURLComponents = URLComponents(string: normalizedUri) else {
            return false
        }
        
        return inputURLComponents.host == uriURLComponents.host
            && inputURLComponents.port == uriURLComponents.port
    }
    
    private func isMatchByPrefixRule(_ input: String, to uri: String) -> Bool {
        let normalizedInput = normalize(input) ?? ""
        let normalizedUri = normalize(uri) ?? ""
        
        return normalizedInput.hasPrefix(normalizedUri)
    }
    
    private func isMatchByExactRule(_ input: String, to uri: String) -> Bool {
        let normalizedInput = normalize(input, options: .doNotRemoveWWW) ?? ""
        let normalizedUri = normalize(uri, options: .doNotRemoveWWW) ?? ""
        
        return normalizedInput == normalizedUri
    }

    private func removeSubdomain(fromHost host: String) -> String? {
        let parts = host.split(separator: ".")
        guard parts.count > 2 else { return host }
        return parts.suffix(2).joined(separator: ".")
    }
    
    private func isValidIPAddress(_ host: String) -> Bool {
        let cleanedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

        var sin = sockaddr_in()
        var sin6 = sockaddr_in6()
        
        return cleanedHost.withCString { cString in
            inet_pton(AF_INET, cString, &sin.sin_addr) == 1 ||
            inet_pton(AF_INET6, cString, &sin6.sin6_addr) == 1
        }
    }
}
