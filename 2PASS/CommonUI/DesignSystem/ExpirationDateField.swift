// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit

public struct ExpirationDateField: View {
    let placeholder: String
    let isInvalid: Bool

    @Binding
    var text: String

    public init(_ placeholder: String, text: Binding<String>, isInvalid: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.isInvalid = isInvalid
    }

    public var body: some View {
        _ExpirationDateTextField(placeholder: placeholder, text: $text, isInvalid: isInvalid)
    }
}

private struct _ExpirationDateTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isInvalid: Bool

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.keyboardType = .numberPad
        textField.delegate = context.coordinator
        textField.text = text
        textField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.textColor = isInvalid ? UIColor(.danger500) : UIColor.label
        if uiView.text != text && !context.coordinator.isEditing {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var previousText = ""
        var isEditing = false
        var shouldAdjustCursorOnFocus = false

        init(text: Binding<String>) {
            self._text = text
            self.previousText = text.wrappedValue
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isEditing = true
            shouldAdjustCursorOnFocus = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isEditing = false
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            // Only adjust cursor position on initial focus
            guard shouldAdjustCursorOnFocus else { return }
            shouldAdjustCursorOnFocus = false

            // If cursor is exactly after "/", move it before
            guard let currentText = textField.text,
                  let slashIndex = currentText.firstIndex(of: "/"),
                  let selectedRange = textField.selectedTextRange else { return }

            let cursorPosition = textField.offset(from: textField.beginningOfDocument, to: selectedRange.start)
            let slashPosition = currentText.distance(from: currentText.startIndex, to: slashIndex)

            if cursorPosition == slashPosition + 1 {
                setCursorPosition(textField, offset: slashPosition)
            }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let currentText = textField.text ?? ""
            guard let textRange = Range(range, in: currentText) else { return false }

            let newText = currentText.replacingCharacters(in: textRange, with: string)

            let isAdding = newText.count > currentText.count
            let isDeleting = newText.count < currentText.count

            if isAdding {
                let insertedDigit = string.filter { $0.isNumber }
                guard !insertedDigit.isEmpty else { return false }

                let isAtEnd = range.location >= currentText.count
                let currentDigits = currentText.filter { $0.isNumber }

                // If at end and already have 4 digits, ignore
                if isAtEnd && currentDigits.count >= 4 {
                    return false
                }

                // Replace mode: if not at end, replace the next digit
                var resultDigits: String
                var cursorDigitPosition: Int

                if isAtEnd {
                    // Add mode at the end
                    resultDigits = currentDigits + insertedDigit
                    cursorDigitPosition = resultDigits.count
                } else {
                    // Replace mode: figure out which digit position we're at
                    var digitPosition = 0
                    for (index, char) in currentText.enumerated() {
                        if index >= range.location { break }
                        if char.isNumber { digitPosition += 1 }
                    }

                    // Replace digit at this position
                    var digits = Array(currentDigits)
                    if digitPosition < digits.count {
                        digits[digitPosition] = insertedDigit.first!
                    } else {
                        digits.append(insertedDigit.first!)
                    }
                    resultDigits = String(digits)
                    cursorDigitPosition = digitPosition + 1
                }

                // Format with slash
                let formatted: String
                let cursorOffset: Int

                if resultDigits.count >= 2 {
                    let month = String(resultDigits.prefix(2))
                    let year = String(resultDigits.dropFirst(2).prefix(2))
                    formatted = month + "/" + year

                    // Calculate cursor position accounting for "/"
                    if cursorDigitPosition <= 2 {
                        cursorOffset = cursorDigitPosition
                    } else {
                        cursorOffset = cursorDigitPosition + 1 // +1 for "/"
                    }
                } else {
                    formatted = resultDigits
                    cursorOffset = cursorDigitPosition
                }

                textField.text = formatted
                text = formatted
                previousText = formatted
                setCursorPosition(textField, offset: cursorOffset)
                return false
                
            } else if isDeleting {
                // When trying to remove "/" with digits after it, remove digit before "/" instead
                if currentText.contains("/") && !newText.contains("/") {
                    let parts = currentText.split(separator: "/", omittingEmptySubsequences: false)
                    if parts.count > 1 && !parts[1].isEmpty {
                        let month = String(parts[0].dropLast())
                        let year = String(parts[1])
                        let formatted = month.isEmpty ? "/" + year : month + "/" + year
                        textField.text = formatted
                        text = formatted
                        previousText = formatted
                        // Keep cursor before the "/"
                        setCursorPosition(textField, offset: month.count)
                        return false
                    }
                }
                // Auto-remove trailing "/"
                if newText.hasSuffix("/") {
                    let formatted = String(newText.dropLast())
                    textField.text = formatted
                    text = formatted
                    previousText = formatted
                    setCursorPosition(textField, offset: formatted.count)
                    return false
                }

                text = newText
                previousText = newText
                return true
            }

            text = newText
            previousText = newText
            return true
        }

        private func setCursorPosition(_ textField: UITextField, offset: Int) {
            if let position = textField.position(from: textField.beginningOfDocument, offset: offset) {
                textField.selectedTextRange = textField.textRange(from: position, to: position)
            }
        }
    }
}
