// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct ExpirationDateField: View {
    let placeholder: String
    let isInvalid: Bool

    @Binding
    var text: String

    @State
    private var previousText = ""

    public init(_ placeholder: String, text: Binding<String>, isInvalid: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.isInvalid = isInvalid
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .foregroundStyle(isInvalid ? .danger500 : .primary)
            .onAppear {
                previousText = text
            }
            .onChange(of: text) { oldValue, newValue in
                // Filter to only digits
                let digitsOnly = newValue.filter { $0.isNumber }

                let isAdding = newValue.count > previousText.count
                let isDeleting = newValue.count < previousText.count

                if isAdding {
                    // Limit to 4 digits (MM + YY)
                    if digitsOnly.count > 4 {
                        let month = String(digitsOnly.prefix(2))
                        let year = String(digitsOnly.dropFirst(2).prefix(2))
                        text = month + "/" + year
                        previousText = text
                        return
                    }

                    // Auto-insert "/" after 2 digits
                    if digitsOnly.count >= 2 {
                        let month = String(digitsOnly.prefix(2))
                        let year = String(digitsOnly.dropFirst(2))
                        text = month + "/" + year
                        previousText = text
                        return
                    }

                    // Only digits before slash
                    if digitsOnly != newValue {
                        text = digitsOnly
                        previousText = text
                        return
                    }
                } else if isDeleting {
                    // Auto-remove trailing "/"
                    if newValue.hasSuffix("/") {
                        text = String(newValue.dropLast())
                        previousText = text
                        return
                    }
                }

                previousText = newValue
            }
    }
}
