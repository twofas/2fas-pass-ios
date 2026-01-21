// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Data
import CommonUI
import Common

struct ConnectPullReqestCommunicationView: View {
    
    @State
    var presenter: ConnectPullReqestCommunicationPresenter
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(\.dismiss)
    private var dismiss
    
    private var isPresentedSuccessToast: Binding<Bool> {
        Binding {
            presenter.state.isSuccess
        } set: { _ in }
    }
    
    @State
    private var questionSensoryFeedback: Bool = false
    
    var body: some View {
        ConnectCommunicationSheetView(title: Text(.requestModalHeaderTitle), identicon: presenter.identicon, webBrowser: presenter.webBrowser, onClose: onClose) {
            ZStack {
                switch presenter.state {
                case .connecting, .finish(.success):
                    progressView
                
                case .action(.changeRequest(let changeRequest)):
                    switch changeRequest {
                    case .addLogin(let passwordDataChangeRequest):
                        addLoginView(changeRequest: passwordDataChangeRequest)
                    case .updateLogin(let loginItem, _):
                        updateLoginView(item: loginItem)
                    case .addSecureNote(let secureNoteDataChangeRequest):
                        addSecureNoteView(changeRequest: secureNoteDataChangeRequest)
                    case .updateSecureNote(let secureNoteItem, _):
                        updateSecureNoteView(item: secureNoteItem)
                    case .addPaymentCard(let paymentCardDataChangeRequest):
                        addPaymentCardView(changeRequest: paymentCardDataChangeRequest)
                    case .updatePaymentCard(let paymentCardItem, _):
                        updatePaymentCardView(item: paymentCardItem)
                    }
                    
                case .action(.delete(let item)):
                    switch item {
                    case .login(let loginItem):
                        deleteLoginView(item: loginItem)
                    case .secureNote(let secureNoteItem):
                        deleteSecureNoteView(item: secureNoteItem)
                    case .paymentCard(let paymentCardItem):
                        deletePaymentCardView(item: paymentCardItem)
                    default:
                        fatalError("Unsupported item content type")
                    }

                case .action(.sifRequest(let item)):
                    switch item {
                    case .login(let loginItem):
                        passwordRequestView(item: loginItem)
                    case .secureNote(let secureNoteItem):
                        noteRequestView(item: secureNoteItem)
                    case .paymentCard(let paymentCardItem):
                        paymentCardRequestView(item: paymentCardItem)
                    default:
                        fatalError("Unsupported item content type")
                    }
                    
                case .action(.sync):
                    syncView()
                    
                case .finish(.failure(let error)):
                   failureView(error: error)
                    
                case .itemsLimitReached(let limit):
                    itemsLimitReachedView(limit: limit)
                }
            }
        }
        .onAppear {
            presenter.onAppear(colorScheme: colorScheme)
        }
        .onDisappear {
            presenter.onDisappear()
        }
        .toast(toastText, isPresented: isPresentedSuccessToast, style: .success)
        .sensoryFeedback(.warning, trigger: questionSensoryFeedback, condition: {
            $1
        })
        .onChange(of: presenter.state, { oldValue, newValue in
            switch newValue {
            case .action:
                Task {
                    try await Task.sleep(for: .milliseconds(100))
                    questionSensoryFeedback = true
                }
            case .finish(.success):
                dismiss()
            case .finish(.failure(let error)):
                if error is CancellationError {
                    dismiss()
                }
                if case ConnectError.cancelled = error {
                    dismiss()
                }
            default:
                break
            }
        })
        .interactiveDismissDisabled()
        .router(router: ConnectPullReqestCommunicationRouter(), destination: $presenter.destination)
    }
    
    private var toastText: Text {
        switch presenter.action {
        case .changeRequest(.updateLogin):
            Text(.requestModalToastSuccessUpdateLogin)
        case .changeRequest(.addLogin):
            Text(.requestModalToastSuccessAddLogin)
        case .changeRequest(.updateSecureNote):
            Text(.requestModalToastSuccessUpdateLogin)
        case .changeRequest(.addSecureNote):
            Text(.requestModalToastSuccessAddLogin)
        case .changeRequest(.updatePaymentCard):
            Text(.requestModalToastSuccessUpdateLogin)
        case .changeRequest(.addPaymentCard):
            Text(.requestModalToastSuccessAddLogin)
        case .delete:
            Text(.requestModalToastSuccessDeleteLogin)
        case .sifRequest(let item):
            switch item {
            case .login:
                Text(.requestModalToastSuccessPasswordRequest)
            case .secureNote:
                Text(.requestModalToastSuccessSecureNoteRequest)
            case .paymentCard:
                Text(.requestModalToastSuccessCardRequest)
            case .raw:
                Text("")
            }
        case .sync:
            Text(.requestModalToastSuccessFullSync)
        case nil:
            Text("")
        }
    }
    
    private func onClose() {
        switch presenter.state {
        case .action:
            presenter.onCancel()
        default:
            dismiss()
        }
    }
    
    private var progressView: some View {
        ProgressView(value: presenter.progress) {
            Text(.connectConnectionConnecting)
        }
        .progressViewStyle(.circle)
        .frame(maxWidth: .infinity)
    }
    
    private func passwordRequestView(item: LoginItemData) -> some View {
        itemRequestView(
            title: Text(.requestModalPasswordRequestTitle),
            subtitle: Text(.requestModalPasswordRequestSubtitle),
            name: item.name ?? "",
            description: item.username
        )
    }

    private func noteRequestView(item: SecureNoteItemData) -> some View {
        itemRequestView(
            title: Text(.requestModalSecureNoteRequestTitle),
            subtitle: Text(.requestModalSecureNoteRequestSubtitle),
            name: item.name ?? "",
            description: nil
        )
    }

    private func paymentCardRequestView(item: PaymentCardItemData) -> some View {
        itemRequestView(
            title: Text(.requestModalCardRequestTitle),
            subtitle: Text(.requestModalCardRequestSubtitle),
            name: item.name ?? "",
            description: item.content.cardNumberMask?.formatted(.paymentCardNumberMask)
        )
    }

    private func itemRequestView(
        title: Text,
        subtitle: Text,
        name: String,
        description: String?
    ) -> some View {
        ConnectPullReqestContentView(
            title: title,
            description: subtitle,
            item: .init(name: name, description: description, iconContent: presenter.iconContent),
            icon: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.brand500)
            },
            actions: {
                Button(.requestModalPasswordRequestCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)

                Button(.requestModalPasswordRequestCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func addLoginView(changeRequest: LoginDataChangeRequest) -> some View {
        addItemView(
            title: Text(.requestModalNewLoginTitle),
            name: changeRequest.name ?? "",
            description: changeRequest.username?.value
        )
    }
    
    private func addSecureNoteView(changeRequest: SecureNoteDataChangeRequest) -> some View {
        addItemView(
            title: Text(.requestModalNewSecureNoteTitle),
            name: changeRequest.name ?? "",
            description: nil
        )
    }

    private func addPaymentCardView(changeRequest: PaymentCardDataChangeRequest) -> some View {
        addItemView(
            title: Text(.requestModalNewCardTitle),
            name: changeRequest.name ?? "",
            description: changeRequest.cardNumber?.formatted(.paymentCardNumberMask)
        )
    }

    private func addItemView(
        title: Text,
        name: String,
        description: String?
    ) -> some View {
        ConnectPullReqestContentView(
            title: title,
            description: Text(.requestModalNewItemSubtitle),
            item: .init(name: name, description: description, iconContent: presenter.iconContent),
            icon: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(.brand500)
            },
            actions: {
                Button(.requestModalNewItemCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)

                Button(.requestModalNewItemCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func updateLoginView(item: LoginItemData) -> some View {
        updateItemView(
            title: Text(.requestModalUpdateLoginTitle),
            name: item.name ?? "",
            description: item.username
        )
    }
    
    private func updateSecureNoteView(item: SecureNoteItemData) -> some View {
        updateItemView(
            title: Text(.requestModalUpdateSecureNoteTitle),
            name: item.name ?? "",
            description: nil
        )
    }

    private func updatePaymentCardView(item: PaymentCardItemData) -> some View {
        updateItemView(
            title: Text(.requestModalUpdateCardTitle),
            name: item.name ?? "",
            description: item.content.cardNumberMask?.formatted(.paymentCardNumberMask)
        )
    }

    private func updateItemView(
        title: Text,
        name: String,
        description: String?
    ) -> some View {
        ConnectPullReqestContentView(
            title: title,
            description: Text(.requestModalUpdateItemSubtitle),
            item: .init(name: name, description: description, iconContent: presenter.iconContent),
            icon: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(.brand500)
            },
            actions: {
                Button(.requestModalUpdateItemCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)

                Button(.requestModalUpdateItemCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func deleteLoginView(item: LoginItemData) -> some View {
        deleteItemView(
            title: Text(.requestModalRemoveLoginTitle),
            name: item.name ?? "",
            description: item.username
        )
    }

    private func deleteSecureNoteView(item: SecureNoteItemData) -> some View {
        deleteItemView(
            title: Text(.requestModalRemoveSecureNoteTitle),
            name: item.name ?? "",
            description: nil
        )
    }

    private func deletePaymentCardView(item: PaymentCardItemData) -> some View {
        deleteItemView(
            title: Text(.requestModalRemoveCardTitle),
            name: item.name ?? "",
            description: item.content.cardNumberMask?.formatted(.paymentCardNumberMask)
        )
    }

    private func deleteItemView(
        title: Text,
        name: String,
        description: String?
    ) -> some View {
        ConnectPullReqestContentView(
            title: title,
            description: Text(.requestModalRemoveItemSubtitle),
            item: .init(name: name, description: description, iconContent: presenter.iconContent),
            icon: {
                Image(systemName: "trash.circle.fill")
                    .foregroundStyle(.danger500)
            },
            actions: {
                Button(.requestModalRemoveItemCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)

                Button(.requestModalRemoveItemCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private func syncView() -> some View {
        ConnectPullReqestContentView(
            title: Text(.requestModalFullSyncTitle),
            description: Text(.requestModalFullSyncSubtitle),
            item: nil,
            icon: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.brand500)
            },
            actions: {
                Button(.requestModalFullSyncCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)
                
                Button(.requestModalFullSyncCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private func failureView(error: Error) -> some View {
        switch error {
        case is CancellationError, ConnectError.cancelled:
            ProgressView(value: presenter.progress) {
                Text(.connectConnectionConnecting)
            }
            .progressViewStyle(.circle)
            .frame(maxWidth: .infinity)

        case ConnectError.missingItem:
            ConnectCommunicationContentView(
                iconColor: .danger500,
                title: Label(.requestModalErrorNoItemTitle, systemImage: "exclamationmark.triangle.fill"),
                description: Text(.requestModalErrorNoItemSubtitle),
                actions: {
                    Button(.requestModalErrorNoItemCta) {
                        dismiss()
                    }
                    .buttonStyle(.bezeled)
                }
            )
        case ConnectPullReqestCommunicationError.sendPasswordDataFailure:
            ConnectCommunicationContentView(
                iconColor: .warning500,
                title: Label(.requestModalErrorSendDataTitle, systemImage: "exclamationmark.triangle.fill"),
                description: Text(.requestModalErrorSendDataSubtitle),
                actions: {
                    Button(.requestModalErrorGenericCta) {
                        dismiss()
                    }
                    .buttonStyle(.bezeled)
                }
            )
        case URLError.notConnectedToInternet:
            ConnectCommunicationContentView(
                iconColor: .danger500,
                title: Label(.connectModalErrorNoInternetTitle, systemImage: "exclamationmark.triangle.fill"),
                description: Text(.connectModalErrorNoInternetSubtitle),
                actions: {
                    Button(.requestModalErrorGenericCta) {
                        dismiss()
                    }
                    .buttonStyle(.bezeled)
                }
            )
        default:
            ConnectCommunicationContentView(
                iconColor: .danger500,
                title: Label(.requestModalErrorGenericTitle, systemImage: "exclamationmark.triangle.fill"),
                description: Text(.requestModalErrorGenericSubtitle),
                actions: {
                    Button(.requestModalErrorGenericCta) {
                        dismiss()
                    }
                    .buttonStyle(.bezeled)
                }
            )
        }
    }
    
    private func itemsLimitReachedView(limit: Int) -> some View {
        ConnectCommunicationContentView(
            iconColor: .danger500,
            title: Label(.requestModalErrorItemsLimitTitle, systemImage: "exclamationmark.triangle.fill"),
            description: Text(.requestModalErrorItemsLimitSubtitle(Int32(limit))),
            actions: {
                Button(.requestModalErrorItemsLimitCta) {
                    dismiss()
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
    }
}
