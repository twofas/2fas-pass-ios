// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemDetailView: View {

    @State
    var presenter: ItemDetailPresenter
        
    var body: some View {
        VStack {
            ItemDetailForm {
                ItemDetailSection {
                    switch presenter.form {
                    case .login(let formPresenter):
                        LoginDetailFormView(presenter: formPresenter)
                    case .secureNote(let formPresenter):
                        SecureNoteDetailFormView(presenter: formPresenter)
                    default:
                        EmptyView()
                    }
                } footer: {
                    if let createdAt = presenter.createdAt, let modifiedAt = presenter.modifiedAt {
                        HStack(alignment: .center, spacing: Spacing.xs) {
                            let verticalSpacing = Spacing.xs

                            VStack(alignment: .leading, spacing: verticalSpacing) {
                                Text(T.commonModified)
                                Text(T.commonCreated)
                            }

                            VStack(alignment: .leading, spacing: verticalSpacing) {
                                Text(modifiedAt)
                                Text(createdAt)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
                        .padding(.top, Spacing.xs)
                    }
                }
            }
            .scrollReadableContentMargins()
        }
        .contentMargins(.top, Spacing.xll)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            presenter.onAppear()
        }
    }
}

#Preview {
    ItemDetailView(presenter: .init(
        itemID: ItemID(),
        flowController: ItemDetailFlowController(viewController: UIViewController()),
        interactor: ItemDetailModulePreviewInteractor(contentType: .login))
    )
}

private class ItemDetailModulePreviewInteractor: ItemDetailModuleInteracting {

    let contentType: ItemContentType
    
    init(contentType: ItemContentType) {
        self.contentType = contentType
    }
    
    func fetchItem(for itemID: ItemID) -> ItemData? {
        switch contentType {
        case .login:
                .login(LoginItemData(
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
                ))
        case .secureNote:
                .secureNote(SecureNoteItemData(
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
                        text: nil
                    )
                ))
        case .unknown(let string):
            fatalError()
        }
    }
    
    func decryptPassword(for itemID: ItemID) -> String? {
        "Password"
    }
    
    func decryptNote(in note: SecureNoteItemData) -> String? {
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum"
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


