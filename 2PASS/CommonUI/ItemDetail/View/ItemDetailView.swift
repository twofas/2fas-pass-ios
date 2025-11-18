// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemDetailView: View {

    enum SelectedField: Hashable {
        case username
        case password
        case url(UUID)
    }

    @State
    var presenter: ItemDetailPresenter

    @State
    var selectedField: SelectedField?
        
    var body: some View {
        VStack {
            Form {
                Section {
                    HStack(spacing: Spacing.m) {
                        IconRendererView(content: presenter.iconContent)
                        
                        Text(presenter.name, format: .itemName)
                            .font(.title3Emphasized)
                            .foregroundStyle(.neutral950)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .padding([.vertical], Spacing.xs)
                    
                    if presenter.isUsernameAvailable, let username = presenter.username {
                        row(key: T.loginUsernameLabel.localizedKey, value: Text(username), field: .username) {
                            UIAction(title: T.loginViewActionCopyUsername, handler: { _ in
                                presenter.onCopyUsername()
                            })
                        }
                        .onChange(of: selectedField == .username) { oldValue, newValue in
                            if newValue {
                                presenter.onSelectUsername()
                            }
                        }
                    }
                    
                    if presenter.isPasswordAvailable, let password = presenter.password {
                        row(
                            key: T.loginPasswordLabel.localizedKey,
                            value: SecureContainerView {
                                HStack {
                                    Spacer()
                                    Text(password).monospaced()
                                }
                            },
                            lineLimit: nil,
                            field: .password
                        ) {
                            UIAction(title: T.loginViewActionCopyPassword, handler: { _ in
                                presenter.onCopyPassword()
                            })
                        }
                        .onChange(of: selectedField == .password) { oldValue, newValue in
                            if newValue {
                                presenter.onSelectPassword()
                            }
                        }
                    }
                    
                    ForEach(Array(presenter.uri.filter({ $0.uriNormalized != nil }).enumerated()), id: \.element.id) { index, uri in
                        if let uriNormalized = uri.uriNormalized {
                            row(key: presenter.uriKey(at: index), value: Text(uri.uri.withZeroWidthSpaces), field: .url(uri.id)) {
                                UIAction(title: T.loginViewActionOpenUri) { _ in
                                    presenter.onOpenURI(uriNormalized)
                                }
                            }
                        }
                    }
                    
                    LabeledContent(T.loginSecurityLevelLabel.localizedKey, value: presenter.protectionLevel.title)
                        .labeledContentStyle(.listCell)
                    
                    if let tags = presenter.tags {
                        LabeledContent(T.loginTags.localizedKey, value: tags)
                            .labeledContentStyle(.listCell(lineLimit: nil))
                    }
                    
                    if let notes = presenter.notes, !notes.isEmpty {
                        Text(notes)
                            .multilineTextAlignment(.leading)
                            .font(.body)
                            .foregroundStyle(.neutral400)
                    }
                } footer: {
                    HStack(alignment: .center, spacing: Spacing.xs) {
                        let verticalSpacing = Spacing.xs
                        
                        VStack(alignment: .leading, spacing: verticalSpacing) {
                            Text(T.commonModified)
                            Text(T.commonCreated)
                        }
                        
                        VStack(alignment: .leading, spacing: verticalSpacing) {
                            Text(presenter.modifiedAt)
                            Text(presenter.createdAt)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
                    .padding(.top, Spacing.xs)
                }
            }
            .scrollReadableContentMargins()
        }
        .contentMargins(.top, Spacing.xll)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
    }
    
    @ViewBuilder
    private func row(key: LocalizedStringKey, value: some View, lineLimit: Int? = 2, field: SelectedField, action: () -> UIAction) -> some View {
        Button {
            selectedField = field
        } label: {
            LabeledContent(key) {
                value
            }
            .contentShape(Rectangle())
            .labeledContentStyle(.listCell(lineLimit: lineLimit))
        }
        .buttonStyle(.twofasPlain)
        .listRowBackground(selectedField == field ? Color.neutral100 : nil)
        .editMenu($selectedField, equals: field, actions: [
            action()
        ])
    }
}

#Preview {
    ItemDetailView(presenter: .init(
        itemID: ItemID(),
        flowController: ItemDetailFlowController(viewController: UIViewController()),
        interactor: ItemDetailModulePreviewInteractor())
    )
}

private class ItemDetailModulePreviewInteractor: ItemDetailModuleInteracting {
    
    func fetchPassword(for itemID: ItemID) -> LoginItemData? {
        LoginItemData(
            id: itemID,
            vaultId: UUID(),
            metadata: .init(
                creationDate: Date(),
                modificationDate: Date(),
                protectionLevel: .topSecret,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: "Preview Name",
            content: .init(
                name: "Preview Name",
                username: "Username",
                password: "Password".data(using: .utf8),
                notes: "Notes",
                iconType: .label(labelTitle: "PR", labelColor: .red),
                uris: nil
            )
        )
    }
    
    func decryptPassword(for itemID: ItemID) -> String? {
        "Password"
    }
    
    func copy(_ str: String) {}
    
    func fetchIconImage(from url: URL) async throws -> Data {
        Data()
    }
    
    func normalizedURL(for uri: PasswordURI) -> URL? {
        nil
    }
    
    func fetchTags(for tagIDs: [ItemTagID]) -> [ItemTagData] {
        []
    }
}


