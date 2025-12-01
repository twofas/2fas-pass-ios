// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import SwiftUIIntrospect

public struct SecureInput: View {
    let label: String
    let isInvalid: Bool

    @State
    private var isReveal = false

    @Binding
    private var value: String

    private var bindingReveal: Binding<Bool>?
    private var introspectTextField: (UITextField) -> Void = { _ in }
    private var isColorized = false
    private var onSubmit: (() -> Void)?

    public init(label: String, value: Binding<String>, reveal: Binding<Bool>? = nil, isInvalid: Bool = false, onSubmit: (() -> Void)? = nil) {
        self.label = label
        self.bindingReveal = reveal
        self._value = value
        self.isInvalid = isInvalid
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack {
            SecureContentInput(label: label, value: $value, isReveal: isReveal, isInvalid: isInvalid)
                .colorized(isColorized)
                .introspect(introspectTextField)
                .onSubmit {
                    onSubmit?()
                }
            
            Spacer()

            Toggle(isOn: $isReveal, label: {})
                .toggleStyle(.reveal)
                .frame(width: 22)
        }
        .onChange(of: isReveal) { oldValue, newValue in
            if let bindingReveal, newValue != bindingReveal.wrappedValue {
                bindingReveal.wrappedValue = newValue
            }
        }
        .onChange(of: bindingReveal?.wrappedValue ?? false) { oldValue, newValue in
            if newValue != isReveal {
                isReveal = newValue
            }
        }
    }
    
    public func introspect(_ introspect: @escaping (UITextField) -> Void) -> Self {
        var instance = self
        instance.introspectTextField = introspect
        return instance
    }
    
    public func colorized(_ isColorized: Bool = true) -> Self {
        var instance = self
        instance.isColorized = isColorized
        return instance
    }
}


public struct SecureContentInput: View {

    private enum Field {
        case unsecure
        case secure
    }

    let label: String
    let isReveal: Bool
    let isInvalid: Bool

    @Binding
    var value: String

    @FocusState
    private var focusedField: Field?

    private var introspectTextField: (UITextField) -> Void = { _ in }
    private var isColorized = false

    public init(label: String, value: Binding<String>, isReveal: Bool = false, isInvalid: Bool = false) {
        self.label = label
        self._value = value
        self.isReveal = isReveal
        self.isInvalid = isInvalid
    }

    public var body: some View {
        ZStack {
            SecureField(label, text: $value)
                .focused($focusedField, equals: .secure)
                .foregroundStyle(isInvalid ? .danger500 : .primary)
                .opacity(isReveal ? 0 : 1)
                .introspect(.textField, on: .iOS(.v17, .v18, .v26)) { textField in
                    introspectTextField(textField)
                }

            SecureContainerView(contentId: value) {
                RevealedPasswordTextField(text: $value, placeholder: label, isColorized: isColorized, isInvalid: isInvalid)
                    .focused($focusedField, equals: .unsecure)
                    .fontDesign(value.isEmpty ? .default : .monospaced)
                    .introspect(.textField, on: .iOS(.v17, .v18, .v26)) { textField in
                        introspectTextField(textField)
                    }
            }
            .opacity(isReveal ? 1 : 0)
        }
        .animation(nil, value: isReveal)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .frame(maxWidth: .infinity)
        .onChange(of: isReveal) { oldValue, newValue in
            if newValue, (focusedField == .secure || focusedField == nil) {
                Task {
                    focusedField = .unsecure
                }
            } else if focusedField == .unsecure || focusedField == nil {
                focusedField = .secure
            }
        }
    }
    
    func introspect(_ introspect: @escaping (UITextField) -> Void) -> Self {
        var instance = self
        instance.introspectTextField = introspect
        return instance
    }
    
    func colorized(_ isColorized: Bool) -> Self {
        var instance = self
        instance.isColorized = isColorized
        return instance
    }
}

private struct RevealedPasswordTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isColorized: Bool
    let isInvalid: Bool

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no

        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        let selectedRange = uiView.selectedTextRange

        if isColorized {
            uiView.attributedText = PasswordRenderer(password: text).makeColorizedNSAttributedString()
        } else {
            uiView.text = text
        }

        if let selectedRange {
            uiView.selectedTextRange = selectedRange
        }

        uiView.placeholder = placeholder
        uiView.textColor = isInvalid ? UIColor(.danger500) : .label

        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        if text.isEmpty == false {
            uiView.font = UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
        } else {
            uiView.font = bodyFont
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: RevealedPasswordTextField
        
        init(_ parent: RevealedPasswordTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}
