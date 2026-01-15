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
        var isEditing = false
        var shouldAdjustCursorOnFocus = false

        private let separator = " / "
        private let maxDigits = 4

        init(text: Binding<String>) {
            self._text = text
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isEditing = true
            shouldAdjustCursorOnFocus = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isEditing = false
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            guard shouldAdjustCursorOnFocus else { return }
            shouldAdjustCursorOnFocus = false

            guard let currentText = textField.text,
                  let sepRange = currentText.range(of: separator),
                  let selectedRange = textField.selectedTextRange else { return }

            let cursor = textField.offset(from: textField.beginningOfDocument, to: selectedRange.start)
            let sepStart = currentText.distance(from: currentText.startIndex, to: sepRange.lowerBound)

            if cursor > sepStart && cursor <= sepStart + separator.count {
                setCursor(textField, at: sepStart)
            }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let currentText = textField.text ?? ""

            if string.isEmpty {
                return handleDeletion(textField, text: currentText, range: range)
            } else {
                return handleInsertion(textField, text: currentText, range: range, input: string)
            }
        }

        // MARK: - Insertion

        private func handleInsertion(
            _ textField: UITextField,
            text currentText: String,
            range: NSRange,
            input: String
        ) -> Bool {
            guard let digit = input.first(where: { $0.isNumber }) else { return false }

            var digits = Array(currentText.filter { $0.isNumber })
            let isAtEnd = range.location >= currentText.count
            let digitPos = digitPosition(in: currentText, at: range.location)

            if isAtEnd {
                guard digits.count < maxDigits else { return false }
                digits.append(digit)
            } else if digits.count < maxDigits {
                digits.insert(digit, at: digitPos)
                if digits.count > maxDigits { digits.removeLast() }
            } else {
                digits[digitPos] = digit
            }

            let cursorDigitPos = isAtEnd ? digits.count : digitPos + 1
            let (formatted, cursorOffset) = format(String(digits), cursorAt: cursorDigitPos)
            apply(textField, text: formatted, cursor: cursorOffset)
            return false
        }

        // MARK: - Deletion

        private func handleDeletion(
            _ textField: UITextField,
            text currentText: String,
            range: NSRange
        ) -> Bool {
            // Deleting within separator with year present → remove last month digit
            if let sepRange = currentText.range(of: separator) {
                let sepStart = currentText.distance(from: currentText.startIndex, to: sepRange.lowerBound)
                let sepEnd = sepStart + separator.count

                if range.location >= sepStart && range.location < sepEnd {
                    let parts = currentText.components(separatedBy: separator)
                    if parts.count > 1 && !parts[1].isEmpty {
                        let month = String(parts[0].dropLast())
                        let year = parts[1]
                        let formatted = month.isEmpty ? separator + year : month + separator + year
                        apply(textField, text: formatted, cursor: month.count)
                        return false
                    }
                }
            }

            // Apply deletion and clean trailing separator fragments
            guard let textRange = Range(range, in: currentText) else { return false }
            let newText = currentText.replacingCharacters(in: textRange, with: "")
            let cleaned = newText.replacingOccurrences(of: "[ /]+$", with: "", options: .regularExpression)

            if cleaned != newText {
                apply(textField, text: cleaned, cursor: cleaned.count)
                return false
            }

            text = newText
            return true
        }

        // MARK: - Helpers

        private func digitPosition(in text: String, at location: Int) -> Int {
            text.prefix(location).filter { $0.isNumber }.count
        }

        private func format(_ digits: String, cursorAt cursorDigitPos: Int) -> (String, Int) {
            guard digits.count >= 2 else {
                return (digits, cursorDigitPos)
            }

            let month = String(digits.prefix(2))
            let year = String(digits.dropFirst(2).prefix(2))
            let formatted = month + separator + year

            let cursorOffset: Int
            if cursorDigitPos < 2 {
                cursorOffset = cursorDigitPos
            } else if cursorDigitPos == 2 && year.isEmpty {
                cursorOffset = formatted.count
            } else {
                cursorOffset = cursorDigitPos + separator.count
            }

            return (formatted, cursorOffset)
        }

        private func apply(_ textField: UITextField, text newText: String, cursor offset: Int) {
            textField.text = newText
            text = newText
            setCursor(textField, at: offset)
        }

        private func setCursor(_ textField: UITextField, at offset: Int) {
            guard let pos = textField.position(from: textField.beginningOfDocument, offset: offset) else { return }
            textField.selectedTextRange = textField.textRange(from: pos, to: pos)
        }
    }
}
