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
    static let minHeightNotes: CGFloat = 80
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
                    
                    Button(T.loginEditIconCta.localizedKey) {
                        presenter.onCustomizeIcon()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bezeled(fillSpace: false, allowGlassEffect: false))
                }
                
                Spacer()
            }
            .listRowBackground(Color.clear)
            
            Section {
                LabeledInput(label: T.loginNameLabel.localizedKey, fieldWidth: $fieldWidth) {
                    TextField(T.loginNameLabel.localizedKey, text: $presenter.name)
                }
                .formFieldChanged(presenter.nameChanged)
                
                usernameField
                    .sheet(isPresented: $presenter.showMostUsed) {
                        mostUsedSheet()
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
                .onChange(of: showURIMatchSettings) { _, current in
                    if !current {
                        currentURI = nil
                    }
                }
                .sheet(isPresented: $showURIMatchSettings) {
                    matchingRuleSheet()
                }
            
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
        LabeledInput(label: T.loginUsernameLabel.localizedKey, fieldWidth: $fieldWidth) {
            HStack {
                TextField(T.loginUsernameLabel.localizedKey, text: $presenter.username)
                    .textContentType(.username)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .focused($focusField, equals: .username)
                    .introspect(.textField, on: .iOS(.v17, .v18, .v26)) {
                        setupUsernameTextField($0)
                    }
            }
        }
        .formFieldChanged(presenter.usernameChanged)
        .font(.body)
    }

    @ViewBuilder
    private var passwordField: some View {
        LabeledInput(label: T.loginPasswordLabel.localizedKey, fieldWidth: $fieldWidth) {
            SecureInput(label: T.loginPasswordPlaceholder.localizedResource, value: $presenter.password)
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
                    TextField(T.loginUriLabel.localizedKey, text: uri.uri)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .frame(maxWidth: .infinity)
                        .focused($focusField, equals: .uri(uri.id))

                    Spacer()

                    Button {
                        currentURI = uri.wrappedValue
                        showURIMatchSettings = true
                    } label: {
                        Image(systemName: "checklist.unchecked")
                            .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
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
                Button(T.loginAddUriCta.localizedKey) {
                    withAnimation {
                        presenter.onAddURI()

                        if let lastURI = presenter.uri.last {
                            focusField = .uri(lastURI.id)
                        }
                    }
                }
            }

        } header: {
            Text(T.loginUriHeader.localizedKey)
        } footer: {
            if let uriError = presenter.uriError {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Asset.destructiveActionColor.swiftUIColor)
                    Text(T.loginUriError(uriError).localizedKey)
                        .font(.caption)
                        .foregroundStyle(Asset.mainTextColor.swiftUIColor)
                }
            }
        }
        .listSectionSpacing(Spacing.l)
    }

    @ViewBuilder
    private var notesSection: some View {
        Section {
            TextField("", text: $presenter.notes, axis: .vertical)
                .focused($focusField, equals: .notes)
                .autocorrectionDisabled(false)
                .textInputAutocapitalization(.sentences)
                .multilineTextAlignment(.leading)
                .limitText($presenter.notes, to: Config.maxNotesLength)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .contentShape(Rectangle())
                .formFieldChanged(presenter.notesChanged)
        } header: {
            Text(T.loginNotesLabel.localizedKey)
        }
        .onTapGesture {
            focusField = .notes
        }
        .listSectionSpacing(Spacing.l)
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
            UIButton(configuration: config, primaryAction: UIAction(title: T.loginPasswordGeneratorCta, image: UIImage(systemName: generateIconName), handler: { [weak presenter] _ in
                presenter?.showGeneratePassword = true
            })),
            UIButton(configuration: config, primaryAction: UIAction(title: T.loginPasswordAutogenerateCta, image: UIImage(systemName: "arrow.clockwise"), handler: { [weak presenter] _ in
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

    private func setupUsernameTextField(_ textField: UITextField) {
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
        
        let mostUsedUsernames = presenter.mostUsedUsernamesForKeyboard()
        guard mostUsedUsernames.isEmpty == false else { return }

        let frame: CGRect
        if #available(iOS 26, *) {
            frame = CGRect(x: 0, y: 0, width: 0, height: Constants.inputAccessoryHeightLiquidGlass)
        } else {
            frame = CGRect(x: 0, y: 0, width: 0, height: Constants.inputAccessoryHeight)
        }

        let inputView = UIInputView(frame: frame, inputViewStyle: .keyboard)

        let buttons = mostUsedUsernames.map { username in
            var config: UIButton.Configuration
            if #available(iOS 26, *) {
                config = UIButton.Configuration.glass()
            } else {
                config = UIButton.Configuration.plain()
                config.baseForegroundColor = .label
            }

            config.titleAlignment = .center
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { container in
                var container = container
                container.font = UIFont.preferredFont(forTextStyle: .footnote)
                return container
            }

            let button = UIButton(configuration: config, primaryAction: UIAction(title: username, handler: { [weak presenter] _ in
                guard let presenter else { return }
                presenter.username = username
                presenter.onFocusField?(presenter.password.isEmpty ? .password : nil)
            }))
            button.titleLabel?.textAlignment = .center
            button.setContentHuggingPriority(.defaultHigh + 1, for: .horizontal)
            return button
        }

        var config: UIButton.Configuration
        if #available(iOS 26, *) {
            config = UIButton.Configuration.glass()
        } else {
            config = UIButton.Configuration.plain()
            config.baseForegroundColor = .label
        }

        let showMoreButton = UIButton(configuration: config, primaryAction: UIAction(image: UIImage(systemName: "person.badge.key"), handler: { [weak presenter] _ in
            presenter?.showMostUsed = true
        }))
        showMoreButton.translatesAutoresizingMaskIntoConstraints = false
        inputView.addSubview(showMoreButton)

        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.setContentHuggingPriority(.defaultHigh + 1, for: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        inputView.addSubview(stackView)

        let isLiquidGlass: Bool
        if #available(iOS 26, *) {
            isLiquidGlass = true
            stackView.spacing = 8
        } else {
            isLiquidGlass = false
        }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: inputView.leadingAnchor, constant: isLiquidGlass ? 16 : 0),
            stackView.topAnchor.constraint(equalTo: inputView.topAnchor, constant: 5),
            stackView.bottomAnchor.constraint(equalTo: inputView.bottomAnchor, constant: isLiquidGlass ? -12 : 0),
            stackView.trailingAnchor.constraint(equalTo: showMoreButton.leadingAnchor, constant: isLiquidGlass ? -16 : 0),

            showMoreButton.trailingAnchor.constraint(equalTo: inputView.trailingAnchor, constant: isLiquidGlass ? -20 : -4),
            showMoreButton.topAnchor.constraint(equalTo: inputView.topAnchor, constant: 5),
            showMoreButton.bottomAnchor.constraint(equalTo: inputView.bottomAnchor, constant: isLiquidGlass ? -12 : 0),
            showMoreButton.widthAnchor.constraint(equalTo: showMoreButton.heightAnchor)
        ])

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
                                            .foregroundStyle(Asset.mainTextColor.swiftUIColor)
                                            .font(.body)
                                        Text(verbatim: match.description)
                                            .font(.caption)
                                            .foregroundStyle(Asset.descriptionTextColor.swiftUIColor)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Asset.accentColor.swiftUIColor)
                                        .isHidden(match != currentURI.match, remove: false)
                                }
                            }
                        }
                    } header: {
                        Spacer(minLength: Spacing.xxl4)
                    } footer: {
                        Text(T.uriSettingsModalDescription.localizedKey)
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
                Text(T.uriSettingsMatchingRuleHeader.localizedKey)
                    .font(.title3Emphasized)
                    .foregroundStyle(Asset.mainTextColor.swiftUIColor)
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

    @ViewBuilder
    private func mostUsedSheet() -> some View {
        NavigationStack {
            VStack(alignment: .leading) {
                let usernames = presenter.mostUsedUsernames()
                if usernames.isEmpty {
                    Text(T.loginUsernameMostUsedEmpty.localizedKey)
                        .font(.subheadline)
                } else {
                    Form {
                        Section {
                            ForEach(presenter.mostUsedUsernames(), id: \.self) { username in
                                Button {
                                    presenter.username = username
                                    presenter.showMostUsed = false

                                    Task {
                                        focusField = nil
                                    }
                                } label: {
                                    Text(verbatim: username)
                                        .foregroundStyle(Asset.mainTextColor.swiftUIColor)
                                        .font(.body)
                                }
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        presenter.showMostUsed = false
                    }
                }
            }
            .navigationTitle(T.loginUsernameMostUsedHeader.localizedKey)
        }
        .presentationDragIndicator(.hidden)
        .presentationDetents([.medium])
    }
}
