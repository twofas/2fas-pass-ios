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
    static let matchingRuleSheetHeight: CGFloat = 420
}

struct AddPasswordView: View {
    
    enum Field: Hashable {
        case username
        case password
        case uri(UUID)
        case notes
    }
    
    @State
    var presenter: AddPasswordPresenter
    var resignFirstResponder: () -> Void
    
    @State
    private var fieldWidth: CGFloat?
    
    @State
    private var showURIMatchSettings = false
    
    @State
    private var showMostUsed = false
    
    @State
    private var currentURI: URI?
    
    @State
    private var showGeneratePassword = false
    
    @State
    private var showDeleteConfirmation = false
    
    @FocusState
    private var focusField: Field?
    
    var body: some View {
        Form {
            HStack {
                Spacer()
                
                VStack(spacing: Spacing.m) {
                    IconRendererView(content: presenter.iconContent)
                        .frame(width: Constants.iconSize, height: Constants.iconSize)
                        .onTapGesture {
                            presenter.onCustomizeIcon()
                        }
                    
                    Button(T.loginEditIconCta.localizedKey) {
                        presenter.onCustomizeIcon()
                    }
                    .controlSize(.small)
                    .buttonStyle(.bezeled(fillSpace: false))
                }
                
                Spacer()
            }
            .listRowBackground(Color.clear)
            
            Section {
                LabeledInput(label: T.loginNameLabel.localizedKey, fieldWidth: $fieldWidth) {
                    TextField(T.loginNameLabel.localizedKey, text: $presenter.name)
                }
                .fieldChanged(presenter.nameChanged)
                
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
                .fieldChanged(presenter.usernameChanged)
                
                LabeledInput(label: T.loginPasswordLabel.localizedKey, fieldWidth: $fieldWidth) {
                    PasswordInput(label: T.loginPasswordPlaceholder.localizedKey, password: $presenter.password)
                        .colorized()
                        .introspect { textField in
                            setupPasswordTextField(textField)
                        }
                        .focused($focusField, equals: .password)
                }
                .fieldChanged(presenter.passwordChanged)
            }
            .font(.body)
            .listSectionSpacing(Spacing.m)
            
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
                    .fieldChanged(presenter.uriChanged(id: uri.id))
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
            
            Section {
                Button {
                    presenter.onChangeProtectionLevel()
                } label: {
                    HStack(spacing: Spacing.s) {
                        Text(T.loginSecurityLevelLabel.localizedKey)
                            .foregroundStyle(Asset.mainTextColor.swiftUIColor)

                        Spacer()
                        
                        Label {
                            Text(presenter.protectionLevel.title.localizedKey)
                        } icon: {
                            presenter.protectionLevel.icon
                                .renderingMode(.template)
                                .foregroundStyle(.accent)
                        }
                        .labelStyle(.rowValue)
                        .foregroundStyle(.neutral500)
                        
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(Asset.inactiveColor.swiftUIColor)
                    }
                    .contentShape(Rectangle())
                }
                .fieldChanged(presenter.protectionLevelChanged)
                .buttonStyle(.plain)
            } header: {
                Text(T.loginSecurityLevelHeader.localizedKey)
            }
            .listSectionSpacing(Spacing.l)
            
            Section {
                Button {
                    presenter.onSelectTags()
                } label: {
                    HStack {
                        Text(T.loginSelectedTags.localizedKey)
                            .foregroundStyle(Asset.mainTextColor.swiftUIColor)
                        
                        Spacer()
                        
                        if !presenter.selectedTags.isEmpty {
                            TagsDisplayView(tags: presenter.selectedTags)
                                .foregroundStyle(.neutral500)
                        } else {
                            Text("(0)")
                                .foregroundStyle(.neutral500)
                        }
                        
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(.neutral500)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text(T.loginTagsHeader.localizedKey)
            } footer: {
                Text(T.loginTagsDescription.localizedKey)
            }
            .listSectionSpacing(Spacing.l)
            
            Section {
                TextField("", text: $presenter.notes, axis: .vertical)
                    .focused($focusField, equals: .notes)
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.sentences)
                    .multilineTextAlignment(.leading)
                    .limitText($presenter.notes, to: Config.maxNotesLength)
                    .frame(maxWidth: .infinity, minHeight: Constants.minHeightNotes, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .fieldChanged(presenter.notesChanged)

            } header: {
                Text(T.loginNotesLabel.localizedKey)
            }
            .onTapGesture {
                focusField = .notes
            }
            .listSectionSpacing(Spacing.l)
            
            if presenter.showRemoveItemButton {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text(T.loginDeleteCta.localizedKey)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(EditMode.active))
        .contentMargins(.top, Spacing.s)
        .formStyle(.grouped)
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
        .alert(T.loginErrorSave.localizedKey, isPresented: $presenter.cantSave) {
            Button(T.commonOk.localizedKey, role: .cancel) {
                presenter.cantSave = false
            }
        }
        .alert(T.loginErrorEditedOtherDevice.localizedKey, isPresented: $presenter.passwordWasEdited) {
            Button(T.commonClose.localizedKey, role: .cancel) {
                presenter.onClose()
            }
        }
        .alert(T.loginErrorDeletedOtherDevice.localizedKey, isPresented: $presenter.passwordWasDeleted) {
            Button(T.commonClose.localizedKey, role: .cancel) {
                presenter.onClose()
            }
        }
        .sheet(isPresented: $showURIMatchSettings) {
            matchingRuleSheet()
        }
        .sheet(isPresented: $showMostUsed) {
            mostUsedSheet()
        }
        .sheet(isPresented: $showGeneratePassword) {
            AddPasswordGenerateRouter.buildView(close: {
                showGeneratePassword = false
            }) { password in
                presenter.password = password
                showGeneratePassword = false
                
                Task {
                    focusField = nil
                }
            }
        }
        .alert(T.loginDeleteConfirmTitle.localizedKey, isPresented: $showDeleteConfirmation, actions: {
            Button(role: .destructive) {
                presenter.onDelete()
            } label: {
                Text(T.commonYes.localizedKey)
            }
            
            Button(role: .cancel) {} label: {
                Text(T.commonNo.localizedKey)
            }
        }, message: {
            Text(T.loginDeleteConfirmBody.localizedKey)
        })
        .onChange(of: showURIMatchSettings) { _, current in
            if !current {
                currentURI = nil
            }
        }
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
        
        let frame = CGRect(x: 0, y: 0, width: 0, height: Constants.inputAccessoryHeight)

        let inputView = UIInputView(frame: frame, inputViewStyle: .keyboard)
        
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .label
        config.imagePadding = 8
        
        let feedback = UIImpactFeedbackGenerator()
        
        let stackView = UIStackView(arrangedSubviews: [
            UIButton(configuration: config, primaryAction: UIAction(title: T.loginPasswordGeneratorCta, image: UIImage(systemName: "gearshape.arrow.trianglehead.2.clockwise.rotate.90"), handler: { _ in
                showGeneratePassword = true
            })),
            UIButton(configuration: config, primaryAction: UIAction(title: T.loginPasswordAutogenerateCta, image: UIImage(systemName: "arrow.clockwise"), handler: { _ in
                presenter.randomPassword()
                feedback.impactOccurred(intensity: 0.5)
            })),
        ])
        
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        
        inputView.addSubview(stackView)
        stackView.pinToParent(with: .init(top: 5, left: 0, bottom: 0, right: 0))

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
        
        let mostUsedUsernames = presenter.mostUsedUsernamesForKeyboard()
        guard mostUsedUsernames.isEmpty == false else { return }
        
        let frame = CGRect(x: 0, y: 0, width: 0, height: Constants.inputAccessoryHeight)

        let inputView = UIInputView(frame: frame, inputViewStyle: .keyboard)
        
        let buttons = mostUsedUsernames.map { username in
            var config = UIButton.Configuration.plain()
            config.baseForegroundColor = .label
            config.titleAlignment = .center
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { container in
                var container = container
                container.font = UIFont.preferredFont(forTextStyle: .footnote)
                return container
            }
            
            let button = UIButton(configuration: config, primaryAction: UIAction(title: username, handler: { _ in
                presenter.username = username
                focusField = presenter.password.isEmpty ? .password : nil
            }))
            button.titleLabel?.textAlignment = .center
            return button
        }
        
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .label
        let showMoreButton = UIButton(configuration: config, primaryAction: UIAction(image: UIImage(systemName: "person.badge.key"), handler: { _ in
            showMostUsed = true
        }))
        showMoreButton.translatesAutoresizingMaskIntoConstraints = false
        inputView.addSubview(showMoreButton)
        
        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.setContentHuggingPriority(.defaultHigh + 1, for: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        inputView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: inputView.leadingAnchor),
            stackView.topAnchor.constraint(equalTo: inputView.topAnchor, constant: 5),
            stackView.bottomAnchor.constraint(equalTo: inputView.bottomAnchor),
            stackView.trailingAnchor.constraint(equalTo: showMoreButton.leadingAnchor),
            
            showMoreButton.trailingAnchor.constraint(equalTo: inputView.trailingAnchor, constant: -4),
            showMoreButton.topAnchor.constraint(equalTo: inputView.topAnchor, constant: 5),
            showMoreButton.bottomAnchor.constraint(equalTo: inputView.bottomAnchor)
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
            }
            
            HStack {
                Text(T.uriSettingsMatchingRuleHeader.localizedKey)
                    .font(.title3Emphasized)
                    .foregroundStyle(Asset.mainTextColor.swiftUIColor)
            
                Spacer()
                
                CloseButton {
                    showURIMatchSettings = false
                }
            }
            .padding(Spacing.l)
        }
        .presentationDetents([.height(Constants.matchingRuleSheetHeight)])
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
                                    showMostUsed = false
                                    
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(T.commonClose.localizedKey, action: { showMostUsed = false }))
            .navigationTitle(T.loginUsernameMostUsedHeader.localizedKey)
        }
        .presentationDragIndicator(.hidden)
        .presentationDetents([.medium])
    }
}

private struct TagsDisplayView: View {
    let tags: [ItemTagData]
    @State private var visibleTagsCount: Int = 0
    @State private var availableWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Array(tags.prefix(visibleTagsCount).enumerated()), id: \.element.tagID) { index, tag in
                    Text(tag.name)
                        .lineLimit(1)
                    
                    if index < visibleTagsCount - 1 {
                        Text(", ")
                    }
                }
                
                if visibleTagsCount < tags.count {
                    Text("(+\(tags.count - visibleTagsCount))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            availableWidth = geometry.size.width
                            calculateVisibleTags(width: availableWidth)
                        }
                        .onChange(of: tags) { _, _ in
                            calculateVisibleTags(width: availableWidth)
                        }
                }
            )
        }
        .frame(height: 20)
    }
    
    private func calculateVisibleTags(width: CGFloat) {
        guard width > 0 else { return }
        
        var totalWidth: CGFloat = 0
        var count = 0
        let font = UIFont.preferredFont(forTextStyle: .body)
        
        // Reserve space for counter if needed
        let counterSpace: CGFloat = tags.count > 1 ? 40 : 0
        let availableSpace = width - counterSpace
        
        for (index, tag) in tags.enumerated() {
            let tagText = tag.name + (index < tags.count - 1 ? ", " : "")
            let textWidth = tagText.size(withAttributes: [.font: font]).width
            
            if totalWidth + textWidth <= availableSpace {
                totalWidth += textWidth
                count += 1
            } else {
                break
            }
        }
        
        // Ensure at least the counter is shown if no tags fit
        if count == 0 && !tags.isEmpty {
            visibleTagsCount = 0
        } else {
            visibleTagsCount = count
        }
    }
}

fileprivate extension View {
    
    func limitText(_ text: Binding<String>, to characterLimit: Int) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            if newValue.count > characterLimit {
                text.wrappedValue = String(text.wrappedValue.prefix(characterLimit))
            }
        }
    }
    
    func fieldChanged(_ changed: Bool) -> some View {
        listRowBackground(changed ? Color.brand50 : nil)
    }
}

#Preview {
    AddPasswordView(
        presenter: AddPasswordPresenter(
            flowController: AddPasswordFlowController(viewController: UIViewController()),
            interactor: ModuleInteractorFactory.shared.addPasswordInteractor(editPasswordID: nil)
        ),
        resignFirstResponder: {}
    )
}
