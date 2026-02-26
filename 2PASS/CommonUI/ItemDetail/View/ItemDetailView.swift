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
                switch presenter.form {
                case .login(let formPresenter):
                    LoginDetailFormView(presenter: formPresenter)
                case .secureNote(let formPresenter):
                    SecureNoteDetailFormView(presenter: formPresenter)
                case .paymentCard(let formPresenter):
                    PaymentCardDetailFormView(presenter: formPresenter)
                case .wifi(let formPresenter):
                    WiFiDetailFormView(presenter: formPresenter)
                default:
                    EmptyView()
                }
                
                VStack(alignment: .leading, spacing: Spacing.l) {
                    tagsView
                    modificationDatesView
                }
                .font(.footnote)
                .foregroundColor(Color(.secondaryLabel))
                .padding(.horizontal, Spacing.xll3)
                .fixedSize(horizontal: false, vertical: true)
            }
            .scrollReadableContentMargins()
        }
        .contentMargins(.top, topMargin)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            presenter.onAppear()
        }
    }
    
    private var topMargin: CGFloat {
        if case .paymentCard = presenter.form {
            return Spacing.s
        } else {
            return Spacing.xll
        }
    }

    @ViewBuilder
    private var tagsView: some View {
        if !presenter.tags.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(.loginTags)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.neutral500)

                MultilineFlowLayout(spacing: Spacing.s, lineSpacing: Spacing.s) {
                    ForEach(presenter.tags) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
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
                            Text(.commonModified)
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
                            Text(.commonCreated)
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
        interactor: ItemDetailModulePreviewInteractor(contentType: .paymentCard))
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
                        tagIds: [UUID(), UUID(), UUID()]
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
                        text: nil,
                        additionalInfo: nil
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
        case .wifi:
                .wifi(WiFiItemData(
                    id: itemID,
                    vaultId: UUID(),
                    metadata: .init(
                        creationDate: Date(),
                        modificationDate: Date(),
                        protectionLevel: .topSecret,
                        trashedStatus: .no,
                        tagIds: nil
                    ),
                    name: "Home Wi-Fi",
                    content: .init(
                        name: "Home Wi-Fi",
                        ssid: "HomeNetwork",
                        password: "SecretPassword".data(using: .utf8),
                        securityType: .wpa2,
                        hidden: false
                    )
                ))
        case .unknown:
            fatalError()
        }
    }
    
    func decryptSecureField(_ data: Data, protectionLevel: ItemProtectionLevel) -> String? {
        String(data: data, encoding: .utf8)
    }

    func makeWiFiQRCodePayload(from data: WiFiQRCodeData) -> String {
        "WIFI:T:WEP;S:SSIDValue;P:PasswordValue;H:true;"
    }
    
    func copy(_ str: String) {}

    func fetchIconImage(from url: URL) async throws -> Data {
        Data()
    }

    func normalizedURL(for uri: PasswordURI) -> URL? {
        nil
    }

    func fetchTags(for tagIDs: [ItemTagID]) -> [ItemTagData] {
        [
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Work", color: .cyan, position: 0, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Personal", color: .green, position: 1, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Finance", color: .indigo, position: 2, modificationDate: Date())
        ]
    }

    func paymentCardSecurityCodeLength(for issuer: PaymentCardIssuer?) -> Int {
        issuer == .americanExpress ? 4 : 3
    }
}
