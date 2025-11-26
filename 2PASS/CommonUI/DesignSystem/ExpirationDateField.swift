// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct ExpirationDateField: View {
    let placeholder: String

    @Binding
    var text: String

    @State
    private var previousText = ""

    public init(placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .onAppear {
                previousText = text
            }
            .onChange(of: text) { oldValue, newValue in
                let isAdding = newValue.count > previousText.count
                let isDeleting = newValue.count < previousText.count

                if isAdding {
                    // Limit to 5 characters (MM/YY)
                    if newValue.count > 5 {
                        text = String(newValue.prefix(5))
                        previousText = text
                        return
                    }

                    // Auto-insert "/" after 2 digits when no slash present
                    let digitsOnly = newValue.filter { $0.isNumber }
                    if digitsOnly.count >= 2 && !newValue.contains("/") {
                        let month = String(digitsOnly.prefix(2))
                        let year = String(digitsOnly.dropFirst(2))
                        text = month + "/" + year
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
