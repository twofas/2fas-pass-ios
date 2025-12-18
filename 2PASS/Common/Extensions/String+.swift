// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public extension String {
    subscript(_ i: Int) -> String {
        let idx1 = index(startIndex, offsetBy: i)
        let idx2 = index(idx1, offsetBy: 1)
        
        return String(self[idx1..<idx2])
    }
    
    subscript(r: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        
        return String(self[start ..< end])
    }
    
    subscript(r: CountableClosedRange<Int>) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: r.lowerBound)
        let endIndex = self.index(startIndex, offsetBy: r.upperBound - r.lowerBound)
        
        return String(self[startIndex...endIndex])
    }
    
    subscript(r: CountablePartialRangeFrom<Int>) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: r.lowerBound)
        
        return String(self[startIndex...])
    }
    
    var localized: String { NSLocalizedString(self, comment: "") }
    
    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isValidLabel: Bool {
        guard !self.isEmpty else { return false }
        let char = Character(self)
        return char.isASCII || char.isLetter || char.isNumber || char.isSymbol || char.isEmoji
    }
    
    var twoLetters: String {
        let value = self.trim()
        guard value.count > 1 else {
            if value.count == 1 {
                return String(value.first ?? Character("")).uppercased()
            }
            return ""
        }
        return value[0...1].uppercased()
    }
    
    var isBackspace: Bool { strcmp(self.cString(using: .utf8), "\\b") == -92 }
    
    static func binaryRepresentation<F: FixedWidthInteger>(of val: F) -> String {
        let binaryString = String(val, radix: 2)
        let paddingCount = val.bitWidth - binaryString.count
        return String(repeating: "0", count: paddingCount) + binaryString
    }
    
    var nonBlankTrimmedOrNil: String? {
        let value = self.trim()
        guard !value.isEmpty else { return nil }
        return value
    }
    
    var nonBlankOrNil: String? {
        let value = self.trim()
        return value.isEmpty ? nil : self
    }

    func sanitizeNotes() -> String? {
        let value = self.trim()
        guard !value.isEmpty else { return nil }
        return String(value.prefix(Config.maxNotesLength))
    }
    
    /// Use it for disable line break strategy
    var withZeroWidthSpaces: String {
        map({ String($0) }).joined(separator: "\u{200B}")
    }
    
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

public extension Optional where Wrapped == String {
    var hasContent: Bool { self != nil && !self!.trim().isEmpty }
    var value: String { self ?? "" }
    var nilIfEmpty: String? {
        guard let self else { return nil }
        let value = self.trim()
        guard !value.isEmpty else { return nil }
        return value
    }
}
