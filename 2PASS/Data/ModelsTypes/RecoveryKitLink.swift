// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

// TODO: Move to interactor, add tests
public final class RecoveryKitLink {
    public static func create(from entropy: Entropy, masterKey: MasterKey?) -> String? {
        var str = "twopass://recovery-kit?entropy=\(entropy.base64EncodedString())"
        if let masterKey {
            str += "&master_key=\(masterKey.base64EncodedString())"
        }
        return str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
    
    public static func parse(from string: String) -> (entropy: String, masterKey: String?)? {
        guard
            let codeStr = handleEncodedCharacters(for: string)?.removingPercentEncoding, !codeStr.isEmpty
        else { return nil }
        
        guard let components = NSURLComponents(string: codeStr) else { return nil }
        guard let scheme = components.scheme, scheme == "twopass" else { return nil }
        guard
            let host = components.host?.trimmingCharacters(in: .init(charactersIn: "/")),
            host == "recovery-kit"
        else { return nil }
        guard let query = components.queryItems else { return nil }
        
        let items = queryItems(query: query)
        
        guard let entropy = items.find(forType: .entropy(""))?.value else { return nil }
        
        let masterKey: String? = items.find(forType: .masterKey(""))?.value
        
        return (entropy: entropy, masterKey: masterKey)
    }
    
    private static func queryItems(query: [URLQueryItem]) -> [QueryItemsType] {
        var values: [QueryItemsType] = []
        
        for item in query {
            guard let value = item.value?.removingPercentEncoding else { continue }
            let parsedItem = QueryItemsType(key: item.name, value: value)
            values.append(parsedItem)
        }
        
        return values
    }
    
    private static func handleEncodedCharacters(for str: String) -> String? {
        let parts = str.split(separator: "?")
        
        guard parts.count < 3 else { return nil }
        
        var completeValue = ""
        
        if let first = parts.first {
            completeValue += replaceEncodedCharacters(for: String(first))
        }
        
        if let second = parts.last {
            completeValue += "?\(removeEncodedCharacters(for: String(second)))"
        }
        
        return completeValue
    }
    
    private static func replaceEncodedCharacters(for str: String) -> String {
        str.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "&amp;", with: "%26")
            .replacingOccurrences(of: "&lt;", with: "%3C")
            .replacingOccurrences(of: "&gt;", with: "%3E")
            .replacingOccurrences(of: "&quot;", with: "%22")
            .replacingOccurrences(of: "&apos;", with: "%27")
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
    }
    
    private static func removeEncodedCharacters(for str: String) -> String {
        str.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
