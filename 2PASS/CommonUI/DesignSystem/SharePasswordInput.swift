// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit
import Common

public struct SharePasswordInput: View {

    @Binding private var text: String
    private var errorMessage: String? = nil
    private var autoFocus = false
    private var introspectHandler: ((UITextField) -> Void)?
    private var shouldReturnHandler: (() -> Bool)?
    private var onSubmitHandler: (() -> Void)?

    @State private var didFocus = false
    @State private var errorShakeTrigger = 0

    private var hasError: Bool { errorMessage != nil }

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        VStack {
            secureInput

            if let errorMessage {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.danger500)
                    Text(errorMessage)
                        .font(.caption1Emphasized)
                        .foregroundStyle(.danger500)
                    Spacer()
                }
                .padding(.horizontal, Spacing.m)
            }
        }
        .onChange(of: hasError) { oldValue, newValue in
            if newValue, !oldValue {
                errorShakeTrigger += 1
            }
        }
    }

    // MARK: - Modifiers

    public func errorMessage(_ message: String?) -> Self {
        var instance = self
        instance.errorMessage = message
        return instance
    }

    public func autoFocus(_ enabled: Bool = true) -> Self {
        var instance = self
        instance.autoFocus = enabled
        return instance
    }

    public func introspect(_ handler: @escaping (UITextField) -> Void) -> Self {
        var instance = self
        instance.introspectHandler = handler
        return instance
    }

    public func shouldReturn(_ handler: @escaping () -> Bool) -> Self {
        var instance = self
        instance.shouldReturnHandler = handler
        return instance
    }

    public func onSubmit(_ handler: @escaping () -> Void) -> Self {
        var instance = self
        instance.onSubmitHandler = handler
        return instance
    }

    // MARK: - Private

    private var secureInput: some View {
        SecureInput(label: .masterPasswordLabel, value: $text)
            .introspect { textField in
                introspectHandler?(textField)

                guard autoFocus, !didFocus else { return }
                DispatchQueue.main.async {
                    guard !didFocus else { return }

                    didFocus = true
                    textField.becomeFirstResponder()

                    if let end = textField.position(from: textField.endOfDocument, offset: 0) {
                        textField.selectedTextRange = textField.textRange(from: end, to: end)
                    }
                }
            }
            .conditionalShouldReturn(shouldReturnHandler)
            .conditionalOnSubmit(onSubmitHandler)
            .padding(.leading, Spacing.l)
            .padding(.trailing, Spacing.xs)
            .frame(height: 44)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.danger500, lineWidth: hasError ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .sensoryFeedback(.error, trigger: errorShakeTrigger)
            .shakeAnimation(trigger: errorShakeTrigger)
    }
}

// MARK: - Conditional Modifiers

private extension SecureInput {
    func conditionalShouldReturn(_ action: (() -> Bool)?) -> SecureInput {
        if let action {
            return shouldReturn(action)
        }
        return self
    }

    func conditionalOnSubmit(_ action: (() -> Void)?) -> SecureInput {
        if let action {
            return onSubmit(action)
        }
        return self
    }
}
