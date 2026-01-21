// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Data

public struct PasswordRenderer {
    
    public let password: String
        
    private let digitColor = UIColor(hexString: "#1FA85B")!
    private let specialColor = UIColor(hexString: "#FF0000")!    
    private let letterColor = UIColor(resource: .mainText)
    
    public init(password: String) {
        self.password = password
    }
    
    public func makeColorizedAttributedString() -> AttributedString {
        password.map { str in
            let str = String(str)
            var attrStr = AttributedString(stringLiteral: str)
            if PasswordCharacterSet.digits.contains(where: { $0 == str }) {
                attrStr.foregroundColor = digitColor
            } else if PasswordCharacterSet.letters.contains(where: { $0 == str }) {
                attrStr.foregroundColor = letterColor
            } else {
                attrStr.foregroundColor = specialColor
            }
            return attrStr
        }
        .reduce(AttributedString()) { partialResult, element in
            var partialResult = partialResult
            partialResult += element
            return partialResult
        }
    }
    
    public func makeColorizedNSAttributedString() -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: password)
        
        for (index, char) in password.enumerated() {
            let str = String(char)
            if PasswordCharacterSet.digits.contains(where: { $0 == str }) {
                attributedString.addAttribute(.foregroundColor, value: digitColor, range: NSRange(location: index, length: 1))
            } else if PasswordCharacterSet.letters.contains(where: { $0 == str }) {
                attributedString.addAttribute(.foregroundColor, value: letterColor, range: NSRange(location: index, length: 1))
            } else {
                attributedString.addAttribute(.foregroundColor, value: specialColor, range: NSRange(location: index, length: 1))
            }
        }
        
        return attributedString
    }
}
