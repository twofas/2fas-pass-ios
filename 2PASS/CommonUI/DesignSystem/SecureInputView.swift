// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

// UIKit secure input with a visibility toggle and screenshot protection in plain mode.
public final class SecureInputView: UIView {

    public var text: String? {
        get { currentTextField.text }
        set {
            secureTextField.text = newValue
            plainTextField.text = newValue
            updateFonts()
            updateColorizationIfNeeded()
        }
    }

    public var isSecure: Bool = true {
        didSet {
            guard oldValue != isSecure else { return }
            updateVisibility(preservingSelectionFrom: oldValue ? secureTextField : plainTextField)
        }
    }

    public var isColorized: Bool = false {
        didSet {
            updateColorizationIfNeeded()
        }
    }

    public var onTextChanged: ((String) -> Void)?
    public var onSubmit: (() -> Void)?
    public var onSecureModeChanged: ((Bool) -> Void)?
    public var showsToggle: Bool = true {
        didSet {
            updateToggleVisibility()
        }
    }

    // Common UITextField forwarding
    public var placeholder: String? {
        get { secureTextField.placeholder }
        set {
            secureTextField.placeholder = newValue
            plainTextField.placeholder = newValue
        }
    }

    public var keyboardType: UIKeyboardType = .default {
        didSet {
            secureTextField.keyboardType = keyboardType
            plainTextField.keyboardType = keyboardType
        }
    }

    public var textContentType: UITextContentType? {
        didSet {
            secureTextField.textContentType = textContentType
            plainTextField.textContentType = textContentType
        }
    }

    public var returnKeyType: UIReturnKeyType = .default {
        didSet {
            secureTextField.returnKeyType = returnKeyType
            plainTextField.returnKeyType = returnKeyType
        }
    }

    public var enablesReturnKeyAutomatically: Bool = false {
        didSet {
            secureTextField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
            plainTextField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
        }
    }

    private let secureTextField = UITextField()
    private let plainTextField = UITextField()
    private let plainProtectedContainer = SecureContainerHostView()
    private let secureToggleButton = UIButton(type: .system)
    private let plainToggleButton = UIButton(type: .system)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        updateVisibility(preservingSelectionFrom: nil)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
        updateVisibility(preservingSelectionFrom: nil)
    }

    // MARK: - Configuration

    private func configureView() {
        configureTextField(secureTextField, isSecure: true)
        configureTextField(plainTextField, isSecure: false)

        configureToggleButton(secureToggleButton)
        configureToggleButton(plainToggleButton)

        secureTextField.rightView = secureToggleButton
        secureTextField.rightViewMode = .always
        plainTextField.rightView = plainToggleButton
        plainTextField.rightViewMode = .always

        addSubview(secureTextField)
        secureTextField.pinToParent()

        addSubview(plainProtectedContainer)
        plainProtectedContainer.pinToParent()
        plainProtectedContainer.embed(plainTextField)

        updateToggleButtonState()
        updateToggleVisibility()
    }

    private func configureTextField(_ textField: UITextField, isSecure: Bool) {
        textField.isSecureTextEntry = isSecure
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        textField.keyboardType = keyboardType
        textField.textContentType = textContentType
        textField.returnKeyType = returnKeyType
        textField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
        textField.textAlignment = .natural
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true

        textField.addTarget(self, action: #selector(textFieldEditingChanged(_:)), for: .editingChanged)
        textField.addTarget(self, action: #selector(textFieldEditingDidEndOnExit(_:)), for: .editingDidEndOnExit)
        textField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    // MARK: - Actions

    @objc private func toggleSecureMode() {
        isSecure.toggle()
        onSecureModeChanged?(isSecure)
    }

    @objc private func textFieldEditingChanged(_ sender: UITextField) {
        let currentText = sender.text ?? ""
        if sender !== secureTextField {
            secureTextField.text = currentText
        }
        if sender !== plainTextField {
            plainTextField.text = currentText
        }
        updateFonts()
        updateColorizationIfNeeded()
        onTextChanged?(currentText)
    }

    @objc private func textFieldEditingDidEndOnExit(_ sender: UITextField) {
        onSubmit?()
    }

    // MARK: - Mode Switching

    private var currentTextField: UITextField {
        isSecure ? secureTextField : plainTextField
    }

    public var activeTextField: UITextField {
        currentTextField
    }

    public func applyExternalTextUpdate(_ newText: String) {
        let targetField = currentTextField
        let selection = selectionOffsets(in: targetField)
        let wasFirstResponder = targetField.isFirstResponder

        secureTextField.text = newText
        plainTextField.text = newText
        updateFonts()
        updateColorizationIfNeeded()

        if wasFirstResponder, let selection {
            restoreSelection(selection, in: targetField)
        }
    }

    private func updateVisibility(preservingSelectionFrom sourceTextField: UITextField?) {
        let sourceField = sourceTextField ?? currentTextField
        let selection = selectionOffsets(in: sourceField)
        let wasFirstResponder = sourceField.isFirstResponder

        secureTextField.isHidden = !isSecure
        plainProtectedContainer.isHidden = isSecure

        updateToggleButtonState()
        updateFonts()

        let targetField = currentTextField
        DispatchQueue.main.async { [weak targetField] in
            guard let targetField else { return }
            if wasFirstResponder {
                targetField.becomeFirstResponder()
            }
            if let selection {
                self.restoreSelection(selection, in: targetField)
            }
        }
    }

    private func selectionOffsets(in textField: UITextField) -> (start: Int, end: Int)? {
        guard let range = textField.selectedTextRange else { return nil }
        let start = textField.offset(from: textField.beginningOfDocument, to: range.start)
        let end = textField.offset(from: textField.beginningOfDocument, to: range.end)
        return (start, end)
    }

    private func restoreSelection(_ selection: (start: Int, end: Int), in textField: UITextField) {
        let textCount = textField.text?.count ?? 0
        let startOffset = min(selection.start, textCount)
        let endOffset = min(selection.end, textCount)

        guard let start = textField.position(from: textField.beginningOfDocument, offset: startOffset),
              let end = textField.position(from: textField.beginningOfDocument, offset: endOffset),
              let range = textField.textRange(from: start, to: end) else { return }
        textField.selectedTextRange = range
    }

    private func updateToggleButtonState() {
        let imageName = isSecure ? "eye" : "eye.slash"
        let label = isSecure ? "Show text" : "Hide text"
        updateToggleButton(secureToggleButton, imageName: imageName, accessibilityLabel: label)
        updateToggleButton(plainToggleButton, imageName: imageName, accessibilityLabel: label)
    }

    private func updateToggleVisibility() {
        secureTextField.rightViewMode = showsToggle ? .always : .never
        plainTextField.rightViewMode = showsToggle ? .always : .never
    }

    private func updateFonts() {
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        secureTextField.font = bodyFont

        let currentText = plainTextField.text ?? ""
        if isSecure == false, currentText.isEmpty == false {
            plainTextField.font = UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
        } else {
            plainTextField.font = bodyFont
        }
    }

    private func updateColorizationIfNeeded() {
        guard isColorized else {
            if plainTextField.attributedText != nil {
                let selection = selectionOffsets(in: plainTextField)
                plainTextField.attributedText = nil
                plainTextField.text = secureTextField.text
                if let selection {
                    restoreSelection(selection, in: plainTextField)
                }
            }
            return
        }

        let text = plainTextField.text ?? ""
        let selection = selectionOffsets(in: plainTextField)
        plainTextField.attributedText = PasswordRenderer(password: text).makeColorizedNSAttributedString()
        if let selection {
            restoreSelection(selection, in: plainTextField)
        }
    }

    private func configureToggleButton(_ button: UIButton) {
        var config = UIButton.Configuration.plain()
        config.imagePlacement = .all
        button.configuration = config
        button.tintColor = .secondaryLabel
        button.accessibilityTraits = .button
        let action = UIAction { [weak self] _ in
            self?.toggleSecureMode()
        }
        button.addAction(action, for: .touchUpInside)
    }

    private func updateToggleButton(_ button: UIButton, imageName: String, accessibilityLabel: String) {
        var config = button.configuration ?? .plain()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        config.image = UIImage(systemName: imageName)?.withConfiguration(symbolConfig)
        button.configuration = config
        button.accessibilityLabel = accessibilityLabel
    }
}

private final class SecureContainerHostView: UIView {
    private let secureContainer: UIView

    override init(frame: CGRect) {
        let secureTextField = UITextField()
        secureTextField.isSecureTextEntry = true
        secureTextField.isUserInteractionEnabled = false

        // This view comes from the secure text field's internal secure layer; rendering inside it
        // keeps content excluded from screenshots and screen recordings on iOS. This relies on
        // UIKit internals and could break with future OS changes.
        if let container = secureTextField.layer.sublayers?.first?.delegate as? UIView {
            secureContainer = container
        } else {
            secureContainer = UIView()
        }

        super.init(frame: frame)

        addSubview(secureContainer)
        secureContainer.pinToParent()
    }

    required init?(coder: NSCoder) {
        let secureTextField = UITextField()
        secureTextField.isSecureTextEntry = true
        secureTextField.isUserInteractionEnabled = false

        if let container = secureTextField.layer.sublayers?.first?.delegate as? UIView {
            secureContainer = container
        } else {
            secureContainer = UIView()
        }

        super.init(coder: coder)

        addSubview(secureContainer)
        secureContainer.pinToParent()
    }

    func embed(_ view: UIView) {
        secureContainer.subviews.forEach { $0.removeFromSuperview() }
        secureContainer.addSubview(view)
        view.pinToParent()
    }
}
