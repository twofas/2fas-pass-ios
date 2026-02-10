// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit

public struct SecureInput: UIViewRepresentable {
    let label: LocalizedStringResource

    @State
    private var isReveal = false

    @Binding
    private var value: String

    private var bindingReveal: Binding<Bool>?
    private var introspectTextField: (UITextField) -> Void = { _ in }
    private var isColorized = false
    private var onSubmit: (() -> Void)?
    private var showsToggle = true

    public init(label: LocalizedStringResource, value: Binding<String>) {
        self.label = label
        self._value = value
    }

    public func makeUIView(context: Context) -> SecureInputView {
        let view = SecureInputView()
        view.onTextChanged = { newText in
            value = newText
        }
        view.onSubmit = onSubmit
        return view
    }

    public func updateUIView(_ uiView: SecureInputView, context: Context) {
        uiView.isSecure = !revealBinding.wrappedValue
        uiView.isColorized = isColorized
        uiView.showsToggle = showsToggle
        uiView.placeholder = String(localized: label)
        uiView.onSubmit = onSubmit
        uiView.onSecureModeChanged = { isSecure in
            let reveal = !isSecure
            if revealBinding.wrappedValue != reveal {
                revealBinding.wrappedValue = reveal
            }
        }

        if uiView.text != value {
            uiView.applyExternalTextUpdate(value)
        }

        introspectTextField(uiView.activeTextField)
    }

    public static func dismantleUIView(_ uiView: SecureInputView, coordinator: ()) {
        // Break potential retain chains from UIKit -> closures -> presenters.
        uiView.onTextChanged = nil
        uiView.onSubmit = nil
        uiView.onSecureModeChanged = nil
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

    public func showsToggle(_ showsToggle: Bool) -> Self {
        var instance = self
        instance.showsToggle = showsToggle
        return instance
    }

    public func onSubmit(_ action: @escaping () -> Void) -> Self {
        var instance = self
        instance.onSubmit = action
        return instance
    }

    public func reveal(_ reveal: Binding<Bool>) -> Self {
        var instance = self
        instance.bindingReveal = reveal
        return instance
    }

    private var revealBinding: Binding<Bool> {
        Binding(
            get: { bindingReveal?.wrappedValue ?? isReveal },
            set: { newValue in
                isReveal = newValue
                bindingReveal?.wrappedValue = newValue
            }
        )
    }
}
