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
        
    @State
    private var datesExpanded = false
    
    var body: some View {
        VStack {
            ItemDetailForm {
                ItemDetailSection {
                    switch presenter.form {
                    case .login(let formPresenter):
                        LoginDetailFormView(presenter: formPresenter)
                    case .secureNote(let formPresenter):
                        SecureNoteDetailFormView(presenter: formPresenter)
                    case .paymentCard(let formPresenter):
                        PaymentCardDetailFormView(presenter: formPresenter)
                    default:
                        EmptyView()
                    }
                } footer: {
                    modificationDatesView
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
    
    @ViewBuilder
    private var modificationDatesView: some View {
        if let createdAt = presenter.createdAt, let modifiedAt = presenter.modifiedAt {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        datesExpanded.toggle()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(T.commonModified)
                                .fontWeight(.semibold)
                            Text(modifiedAt)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20))
                            .foregroundStyle(.accent)
                            .rotationEffect(.degrees(datesExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.twofasPlain)
                
                if datesExpanded {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(T.commonCreated)
                                .fontWeight(.semibold)
                            Text(createdAt)
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(.neutral500)
            .padding(.top, Spacing.xs)
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
        case .paymentCard:
                .paymentCard(PaymentCardItemData(
                    id: itemID,
                    vaultId: UUID(),
                    metadata: .init(
                        creationDate: Date(),
                        modificationDate: Date(),
                        protectionLevel: .topSecret,
                        trashedStatus: .no,
                        tagIds: nil
                    ),
                    name: "Preview Card",
                    content: .init(
                        name: "Preview Card",
                        cardHolder: "John Doe",
                        cardIssuer: "Visa",
                        cardNumber: nil,
                        cardNumberMask: "1234",
                        expirationDate: nil,
                        securityCode: nil,
                        notes: "Notes"
                    )
                ))
        case .unknown:
            fatalError()
        }
    }

    func decryptSecureField(_ data: Data, protectionLevel: ItemProtectionLevel) -> String? {
        String(data: data, encoding: .utf8)
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


