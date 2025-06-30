// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension String {
    public func sanitizeForFileName() -> String {
        let withoutDiacritics = removeDiacritics(self)
        let sanitized = sanitizeFileName(withoutDiacritics)
        let withoutSpaces = replaceSpaces(sanitized)
        let truncated = truncateFileName(withoutSpaces)
        return truncated
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")
        return fileName.components(separatedBy: illegalCharacters).joined()
    }
    
    private func truncateFileName(_ fileName: String, maxLength: Int = 64) -> String {
        String(fileName.prefix(maxLength))
    }
    
    private func replaceSpaces(_ fileName: String) -> String {
        fileName.replacingOccurrences(of: " ", with: "_")
    }
    
    private func removeDiacritics(_ fileName: String) -> String {
        fileName.folding(options: .diacriticInsensitive, locale: .current)
    }
}
