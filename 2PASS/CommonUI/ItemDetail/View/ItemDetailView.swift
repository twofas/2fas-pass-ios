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
            Form {
                Section {
                    switch presenter.form {
                    case .login(let presenter):
                        LoginDetailFormView(presenter: presenter)
                    case .secureNote(let presenter):
                        SecureNoteDetailFormView(presenter: presenter)
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
        interactor: ItemDetailModulePreviewInteractor())
    )
}

private class ItemDetailModulePreviewInteractor: ItemDetailModuleInteracting {

    func fetchItem(for itemID: ItemID) -> ItemData? {
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
    }
    
    func decryptPassword(for itemID: ItemID) -> String? {
        "Password"
    }
    
    func decryptNote(in note: SecureNoteItemData) -> String? {
        "Note"
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


