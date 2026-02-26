// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import SwiftUIIntrospect

private struct Constants {
    static let iconSize: CGFloat = 60
    static let iconPlaceholderCornerRadius: CGFloat = 16
    static let inputAccessoryHeight: CGFloat = 44
    static let inputAccessoryHeightLiquidGlass: CGFloat = 64
    static let matchingRuleSheetHeight: CGFloat = 420
    static let matchingRuleSheetHeightLiquidGlass: CGFloat = 460
}

struct LoginEditorFormView: View {

    enum Field: Hashable {
        case username
        case password
        case uri(UUID)
        case notes
    }
    
    @Bindable
    var presenter: LoginEditorFormPresenter
        
    let resignFirstResponder: Callback
    
    @FocusState
    private var focusField: Field?
    
    @State
    private var fieldWidth: CGFloat?

    @State
    private var showURIMatchSettings = false

    @State
    private var currentURI: URI?

    var body: some View {
        Group {
            HStack {
                Spacer()
                
                VStack(spacing: Spacing.m) {
                    IconRendererView(content: presenter.iconContent)
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                        .onTapGesture {
                            resignFirstResponder()
                            presenter.onCustomizeIcon()
                        }
                    
                    Button(.loginEditIconCta) {
                        presenter.onCustomizeIcon()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bezeled(fillSpace: false, allowGlassEffect: false))
                }
                
                Spacer()
            }
            .listRowBackground(Color.clear)
            
            Section {
                LabeledInput(label: String(localized: .loginNameLabel), fieldWidth: $fieldWidth) {
                    TextField(String(localized: .loginNameLabel), text: $presenter.name)
                }
                .formFieldChanged(presenter.nameChanged)
                
                usernameField
                    .sheet(isPresented: $presenter.showMostUsed) {
                        MostUsedUsernamesSheet(
                            usernames: presenter.mostUsedUsernames(),
                            onSelect: { username in
                                presenter.username = username
                                presenter.showMostUsed = false
                                Task {
                                    focusField = nil
                                }
                            },
                            onCancel: {
                                presenter.showMostUsed = false
                            }
                        )
                    }
                
                passwordField
                    .sheet(isPresented: $presenter.showGeneratePassword) {
                        PasswordGeneratorRouter.buildView(close: {
                            presenter.showGeneratePassword = false
                        }) { password in
                            presenter.password = password
                            presenter.showGeneratePassword = false

                            Task {
                                focusField = nil
                            }
                        }
                    }
            }
            .font(.body)
            .listSectionSpacing(Spacing.m)
            
            urisSection
            
            ItemEditorProtectionLevelSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
            ItemEditorTagsSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
            
            notesSection
        }
        .onAppear {
            presenter.onFocusField = {
                focusField = $0
            }
        }
        .onDisappear {
            presenter.onFocusField = nil
        }
    }
    
    private var usernameField: some View {
        LabeledInput(label: String(localized: .loginUsernameLabel), fieldWidth: $fieldWidth) {
            HStack {
                UsernameTextField(
                    text: $presenter.username,
                    placeholder: .loginUsernameLabel,
                    mostUsedUsernames: presenter.mostUsedUsernamesForKeyboard(),
                    onSelectUsername: { username in
                        presenter.username = username
                        presenter.onFocusField?(presenter.password.isEmpty ? .password : nil)
                    },
                    onShowMoreTapped: {
                        presenter.showMostUsed = true
                    }
                )
            }
        }
        .formFieldChanged(presenter.usernameChanged)
        .font(.body)
    }

    @ViewBuilder
    private var passwordField: some View {
        LabeledInput(label: String(localized: .loginPasswordLabel), fieldWidth: $fieldWidth) {
            SecureInput(label: .loginPasswordPlaceholder, value: $presenter.password)
                .colorized()
                .introspect { textField in
                    setupPasswordTextField(textField)
                }
                .focused($focusField, equals: .password)
        }
        .formFieldChanged(presenter.passwordChanged)
        .font(.body)
    }

    @ViewBuilder
    private var urisSection: some View {
        Section {
            ForEach($presenter.uri, id: \.id) { uri in
                HStack {
                    TextField(String(localized: .loginUriLabel), text: uri.uri)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .frame(maxWidth: .infinity)
                        .focused($focusField, equals: .uri(uri.id))

                    Spacer()

                    Button {
                        currentURI = uri.wrappedValue
                        showURIMatchSettings = true
                    } label: {
                        Image(systemName: "checklist.unchecked")
                            .foregroundStyle(.labelSecondary)
                    }
                    .buttonStyle(.borderless)
                    .frame(alignment: .trailing)
                }
                .formFieldChanged(presenter.uriChanged(id: uri.id))
            }
            .onDelete { indexSet in
                presenter.onRemoveURI(atOffsets: indexSet)
            }

            if presenter.uri.count < presenter.maxURICount {
                Button(.loginAddUriCta) {
                    withAnimation {
                        presenter.onAddURI()

                        if let lastURI = presenter.uri.last {
                            focusField = .uri(lastURI.id)
                        }
                    }
                }
            }

        } header: {
            Text(.loginUriHeader)
                .sheet(isPresented: $showURIMatchSettings) { // placed here to work around an iOS auto-close bug
                    matchingRuleSheet()
                }
        } footer: {
            if let uriError = presenter.uriError {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.destructiveAction)
                    Text(.loginUriError(uriError))
                        .font(.caption)
                        .foregroundStyle(.mainText)
                }
            }
        }
        .listSectionSpacing(Spacing.l)
        .onChange(of: showURIMatchSettings) { _, current in
            if !current {
                currentURI = nil
            }
        }
    }

    private var notesSection: some View {
        ItemEditorNotesSection(
            notes: $presenter.notes,
            notesChanged: presenter.notesChanged,
            focusField: $focusField,
            focusedField: .notes,
            header: .loginNotesLabel
        )
    }

    private func setupPasswordTextField(_ textField: UITextField) {
        textField.textContentType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        textField.keyboardType = .asciiCapable
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []

        guard textField.inputAccessoryView == nil else { return }
        
        let frame: CGRect
        if #available(iOS 26.0, *) {
            frame = CGRect(x: 0, y: 0, width: 0, height: Constants.inputAccessoryHeightLiquidGlass)
        } else {
            frame = CGRect(x: 0, y: 0, width: 0, height: Constants.inputAccessoryHeight)
        }
        
        let inputView = UIInputView(frame: frame, inputViewStyle: .keyboard)

        var config: UIButton.Configuration
        if #available(iOS 26.0, *) {
            config = UIButton.Configuration.glass()
        } else {
            config = UIButton.Configuration.plain()
            config.baseForegroundColor = .label
        }

        config.imagePadding = 8

        let feedback = UIImpactFeedbackGenerator()

        let generateIconName: String = {
            if #available(iOS 18.0, *) {
                return "gearshape.arrow.trianglehead.2.clockwise.rotate.90"
            } else {
                return "gearshape.arrow.triangle.2.circlepath"
            }
        }()

        let stackView = UIStackView(arrangedSubviews: [
            UIButton(configuration: config, primaryAction: UIAction(title: String(localized: .loginPasswordGeneratorCta), image: UIImage(systemName: generateIconName), handler: { [weak presenter] _ in
                presenter?.showGeneratePassword = true
            })),
            UIButton(configuration: config, primaryAction: UIAction(title: String(localized: .loginPasswordAutogenerateCta), image: UIImage(systemName: "arrow.clockwise"), handler: { [weak presenter] _ in
                guard let presenter else { return }
                presenter.randomPassword()
                feedback.impactOccurred(intensity: 0.5)
            })),
        ])

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually

        inputView.addSubview(stackView)

        if #available(iOS 26.0, *) {
            stackView.spacing = 16
            stackView.pinToParent(with: .init(top: 5, left: 16, bottom: 12, right: 16))
        } else {
            stackView.pinToParent(with: .init(top: 5, left: 0, bottom: 0, right: 0))
        }

        textField.inputAccessoryView = inputView
    }

    @ViewBuilder
    private func matchingRuleSheet() -> some View {
        ZStack(alignment: .top) {
            if let currentURI {
                Form {
                    Section {
                        ForEach(PasswordURI.Match.allCases, id: \.self) { match in
                            Button {
                                self.currentURI?.match = match
                                presenter.onSelectMatch(currentURI.id, match: match)
                                showURIMatchSettings = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(verbatim: match.title)
                                            .foregroundStyle(.mainText)
                                            .font(.body)
                                        Text(verbatim: match.description)
                                            .font(.caption)
                                            .foregroundStyle(.descriptionText)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                        .isHidden(match != currentURI.match, remove: false)
                                }
                            }
                        }
                    } header: {
                        Spacer(minLength: Spacing.xxl4)
                    } footer: {
                        Text(.uriSettingsModalDescription)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.s)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .modify {
                    if #available(iOS 26, *) {
                        $0.contentMargins(.top, Spacing.xxl4)
                    } else {
                        $0
                    }
                }
            }

            HStack {
                Text(.uriSettingsMatchingRuleHeader)
                    .font(.title3Emphasized)
                    .foregroundStyle(.mainText)
                    .modify {
                        if #available(iOS 26, *) {
                            $0.padding(.leading, Spacing.s)
                        } else {
                            $0
                        }
                    }

                Spacer()

                CloseButton {
                    showURIMatchSettings = false
                }
            }
            .modify {
                if #available(iOS 26, *) {
                    $0.padding(.top, Spacing.xs)
                } else {
                    $0
                }
            }
            .padding(Spacing.l)
        }
        .modify {
            if #available(iOS 26, *) {
                $0.presentationDetents([.height(Constants.matchingRuleSheetHeightLiquidGlass)])
            } else {
                $0.presentationDetents([.height(Constants.matchingRuleSheetHeight)])
            }
        }
    }

}
