// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import SwiftUIIntrospect

public struct PasswordInput: View {
    let label: LocalizedStringKey
    
    @State
    private var isReveal = false
    
    @Binding
    private var password: String
    
    private var bindingReveal: Binding<Bool>?
    private var introspectTextField: (UITextField) -> Void = { _ in }
    private var isColorized = false
    private var hideRevealButton = false
    private var onSubmit: (() -> Void)?
    
    public init(label: LocalizedStringKey, password: Binding<String>, reveal: Binding<Bool>? = nil, onSubmit: (() -> Void)? = nil) {
        self.label = label
        self.bindingReveal = reveal
        self._password = password
        self.onSubmit = onSubmit
    }
    
    public var body: some View {
        HStack {
            PasswordContentInput(label: label, password: $password, isReveal: isReveal)
                .colorized(isColorized)
                .introspect(introspectTextField)
                .onSubmit {
                    onSubmit?()
                }
            
            Spacer()
            
            Toggle(isOn: $isReveal, label: {})
                .toggleStyle(RevealToggleStyle())
                .frame(width: 22)
                .opacity(hideRevealButton ? 0 : 1)
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
    
    public func hideRevealButton(_ hide: Bool = true) -> Self {
        var instance = self
        instance.hideRevealButton = hide
        return instance
    }
    
    public func colorized(_ isColorized: Bool = true) -> Self {
        var instance = self
        instance.isColorized = isColorized
        return instance
    }
}

public struct RevealToggleStyle: ToggleStyle {
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.$isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "eye.slash" : "eye")
                .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
        }
    }
}

public struct PasswordContentInput: View {
    
    private enum Field {
        case unsecure
        case secure
    }
    
    let label: LocalizedStringKey
    let isReveal: Bool
    
    @Binding
    var password: String
    
    @FocusState
    private var focusedField: Field?
    
    private var introspectTextField: (UITextField) -> Void = { _ in }
    private var isColorized = false
    
    public init(label: LocalizedStringKey, password: Binding<String>, isReveal: Bool = false) {
        self.label = label
        self._password = password
        self.isReveal = isReveal
    }
    
    public var body: some View {
        ZStack {
            SecureField(label, text: $password)
                .focused($focusedField, equals: .secure)
                .opacity(isReveal ? 0 : 1)
                .introspect(.textField, on: .iOS(.v17, .v18, .v26)) { textField in
                    introspectTextField(textField)
                }
            
            SecureContainerView(contentId: password) {
                RevealedPasswordTextField(text: $password, isColorized: isColorized)
                    .focused($focusedField, equals: .unsecure)
                    .fontDesign(password.isEmpty ? .default : .monospaced)
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
    let isColorized: Bool
    
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
        if isColorized {
            uiView.attributedText = PasswordRenderer(password: text).makeColorizedNSAttributedString()
        } else {
            uiView.text = text
        }
        
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        uiView.font = UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
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
