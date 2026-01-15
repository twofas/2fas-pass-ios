// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct PaymentCardNumberTextField: View {
    let placeholder: String
    let maxLength: Int
    let formatStyle: PaymentCardNumberFormatStyle
    let isInvalid: Bool

    @Binding
    var text: String

    public init(
        _ placeholder: String,
        text: Binding<String>,
        maxLength: Int,
        formatStyle: PaymentCardNumberFormatStyle,
        isInvalid: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.maxLength = maxLength
        self.formatStyle = formatStyle
        self.isInvalid = isInvalid
    }

    public var body: some View {
        SecureContainerView {
            _PaymentCardNumberTextField(
                placeholder: placeholder,
                maxLength: maxLength,
                formatStyle: formatStyle,
                isInvalid: isInvalid,
                text: $text
            )
        }
    }
}

private struct _PaymentCardNumberTextField: UIViewRepresentable {
    let placeholder: String
    let maxLength: Int
    let formatStyle: PaymentCardNumberFormatStyle
    let isInvalid: Bool

    @Binding
    var text: String

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .asciiCapableNumberPad
        textField.textContentType = .creditCardNumber
        textField.delegate = context.coordinator
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        textField.font = .monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)

        // Set placeholder with regular (non-monospace) font
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.placeholderText
            ]
        )

        textField.setContentHuggingPriority(.required, for: .vertical)
        textField.setContentCompressionResistancePriority(.required, for: .vertical)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.text = text
        return textField
    }

    public func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.maxLength = maxLength
        context.coordinator.formatStyle = formatStyle

        let isFocused = textField.isFirstResponder
        if isFocused {
            let formatted = formatStyle.format(text)
            if textField.text != formatted {
                textField.text = formatted
            }
        } else {
            if textField.text != text {
                textField.text = text
            }
        }

        // Update placeholder with regular (non-monospace) font
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.placeholderText
            ]
        )

        textField.textColor = isInvalid ? UIColor(.danger500) : .label
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: _PaymentCardNumberTextField
        var maxLength: Int
        var formatStyle: PaymentCardNumberFormatStyle
        private var previousText = ""

        init(_ parent: _PaymentCardNumberTextField) {
            self.parent = parent
            self.maxLength = parent.maxLength
            self.formatStyle = parent.formatStyle
            self.previousText = parent.text
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            let formatted = formatStyle.format(parent.text)
            textField.text = formatted
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            textField.text = parent.text
        }

        public func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {

            let currentText = textField.text ?? ""

            guard let textRange = Range(range, in: currentText) else {
                return false
            }

            let newText = currentText.replacingCharacters(in: textRange, with: string)
            let isDeleting = string.isEmpty && range.length > 0

            var digitsOnly = newText.filter { $0.isNumber }

            // Limit to max card number length based on issuer
            if digitsOnly.count > maxLength {
                digitsOnly = String(digitsOnly.prefix(maxLength))
            }

            // Calculate cursor position in digits
            var cursorDigitPosition: Int

            if isDeleting {
                // Check if user deleted a space
                let deletedChar = currentText[textRange]
                if deletedChar == " " {
                    // User deleted a space - also remove the digit before it
                    let digitsBeforeCursor = currentText[..<textRange.lowerBound].filter { $0.isNumber }.count
                    if digitsBeforeCursor > 0 {
                        var digits = Array(digitsOnly)
                        let indexToRemove = digitsBeforeCursor - 1
                        if indexToRemove < digits.count {
                            digits.remove(at: indexToRemove)
                            digitsOnly = String(digits)
                        }
                    }
                    cursorDigitPosition = currentText[..<textRange.lowerBound].filter { $0.isNumber }.count - 1
                } else {
                    cursorDigitPosition = currentText[..<textRange.lowerBound].filter { $0.isNumber }.count
                }
            } else {
                // Adding characters
                let digitsBeforeCursor = currentText[..<textRange.lowerBound].filter { $0.isNumber }.count
                let addedDigits = string.filter { $0.isNumber }.count
                cursorDigitPosition = digitsBeforeCursor + addedDigits
            }

            cursorDigitPosition = max(0, cursorDigitPosition)

            // Format the number
            let formatted = formatStyle.format(digitsOnly)

            // Calculate new cursor position in formatted string
            var newCursorPosition = 0
            var digitCount = 0
            for char in formatted {
                if digitCount >= cursorDigitPosition {
                    break
                }
                newCursorPosition += 1
                if char.isNumber {
                    digitCount += 1
                }
            }

            // Update text field
            textField.text = formatted
            parent.text = formatted
            previousText = formatted

            // Set cursor position
            if let newPosition = textField.position(from: textField.beginningOfDocument, offset: newCursorPosition) {
                textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
            }

            return false
        }
    }
}
