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
        ConnectCommunicationSheetView(title: Text(T.requestModalHeaderTitle), identicon: presenter.identicon, webBrowser: presenter.webBrowser, onClose: onClose) {
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
                    }
                    
                case .action(.delete(let item)):
                    switch item {
                    case .login(let loginItem):
                        deleteLoginView(item: loginItem)
                    case .secureNote(let secureNoteItem):
                        deleteSecureNoteView(item: secureNoteItem)
                    default:
                        fatalError("Unsupported item content type")
                    }
                    
                case .action(.sifRequest(let item)):
                    switch item {
                    case .login(let loginItem):
                        passwordRequestView(item: loginItem)
                    case .secureNote(let secureNoteItem):
                        noteRequestView(item: secureNoteItem)
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
            Text(T.requestModalToastSuccessUpdateLogin.localizedKey)
        case .changeRequest(.addLogin):
            Text(T.requestModalToastSuccessAddLogin.localizedKey)
        case .changeRequest(.updateSecureNote):
            Text(T.requestModalToastSuccessUpdateLogin.localizedKey)
        case .changeRequest(.addSecureNote):
            Text(T.requestModalToastSuccessAddLogin.localizedKey)
        case .delete:
            Text(T.requestModalToastSuccessDeleteLogin.localizedKey)
        case .sifRequest(let item):
            switch item {
            case .login:
                Text(T.requestModalToastSuccessPasswordRequest.localizedKey)
            case .secureNote:
                Text(T.requestModalToastSuccessSecureNoteRequest.localizedKey)
            case .raw:
                Text("")
            }
        case .sync:
            Text(T.requestModalToastSuccessFullSync.localizedKey)
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
            Text(T.connectConnectionConnecting.localizedKey)
        }
        .progressViewStyle(.circle)
        .frame(maxWidth: .infinity)
    }
    
    private func passwordRequestView(item: LoginItemData) -> some View {
        itemRequestView(
            title: Text(T.requestModalPasswordRequestTitle.localizedKey),
            subtitle: Text(T.requestModalPasswordRequestSubtitle.localizedKey),
            name: item.name ?? "",
            description: item.username
        )
    }

    private func noteRequestView(item: SecureNoteItemData) -> some View {
        itemRequestView(
            title: Text(T.requestModalSecureNoteRequestTitle.localizedKey),
            subtitle: Text(T.requestModalSecureNoteRequestSubtitle.localizedKey),
            name: item.name ?? "",
            description: nil
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
                Button(T.requestModalPasswordRequestCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)

                Button(T.requestModalPasswordRequestCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func addLoginView(changeRequest: LoginDataChangeRequest) -> some View {
        addItemView(
            title: Text(T.requestModalNewLoginTitle.localizedKey),
            name: changeRequest.name ?? "",
            description: changeRequest.username?.value
        )
    }
    
    private func addSecureNoteView(changeRequest: SecureNoteDataChangeRequest) -> some View {
        addItemView(
            title: Text(T.requestModalNewSecureNoteTitle.localizedKey),
            name: changeRequest.name ?? "",
            description: nil
        )
    }

    private func addItemView(
        title: Text,
        name: String,
        description: String?
    ) -> some View {
        ConnectPullReqestContentView(
            title: title,
            description: Text(T.requestModalNewItemSubtitle.localizedKey),
            item: .init(name: name, description: description, iconContent: presenter.iconContent),
            icon: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(.brand500)
            },
            actions: {
                Button(T.requestModalNewItemCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)

                Button(T.requestModalNewItemCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func updateLoginView(item: LoginItemData) -> some View {
        updateItemView(
            title: Text(T.requestModalUpdateLoginTitle.localizedKey),
            name: item.name ?? "",
            description: item.username
        )
    }
    
    private func updateSecureNoteView(item: SecureNoteItemData) -> some View {
        updateItemView(
            title: Text(T.requestModalUpdateSecureNoteTitle.localizedKey),
            name: item.name ?? "",
            description: nil
        )
    }

    private func updateItemView(
        title: Text,
        name: String,
        description: String?
    ) -> some View {
        ConnectPullReqestContentView(
            title: title,
            description: Text(T.requestModalUpdateItemSubtitle.localizedKey),
            item: .init(name: name, description: description, iconContent: presenter.iconContent),
            icon: {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(.brand500)
            },
            actions: {
                Button(T.requestModalUpdateItemCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)

                Button(T.requestModalUpdateItemCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func deleteLoginView(item: LoginItemData) -> some View {
        deleteItemView(
            title: Text(T.requestModalRemoveLoginTitle.localizedKey),
            name: item.name ?? "",
            description: item.username
        )
    }

    private func deleteSecureNoteView(item: SecureNoteItemData) -> some View {
        deleteItemView(
            title: Text(T.requestModalRemoveSecureNoteTitle.localizedKey),
            name: item.name ?? "",
            description: nil
        )
    }

    private func deleteItemView(
        title: Text,
        name: String,
        description: String?
    ) -> some View {
        ConnectPullReqestContentView(
            title: title,
            description: Text(T.requestModalRemoveItemSubtitle.localizedKey),
            item: .init(name: name, description: description, iconContent: presenter.iconContent),
            icon: {
                Image(systemName: "trash.circle.fill")
                    .foregroundStyle(.danger500)
            },
            actions: {
                Button(T.requestModalRemoveItemCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)

                Button(T.requestModalRemoveItemCtaPositive) {
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private func syncView() -> some View {
        ConnectPullReqestContentView(
            title: Text(T.requestModalFullSyncTitle.localizedKey),
            description: Text(T.requestModalFullSyncSubtitle.localizedKey),
            item: nil,
            icon: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.brand500)
            },
            actions: {
                Button(T.requestModalFullSyncCtaNegative) {
                    presenter.onCancel()
                }
                .buttonStyle(.bezeledGray)
                
                Button(T.requestModalFullSyncCtaPositive) {
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
                Text(T.connectConnectionConnecting.localizedKey)
            }
            .progressViewStyle(.circle)
            .frame(maxWidth: .infinity)

        case ConnectError.missingItem:
            ConnectCommunicationContentView(
                iconColor: .danger500,
                title: Label(T.requestModalErrorNoItemTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                description: Text(T.requestModalErrorNoItemSubtitle.localizedKey),
                actions: {
                    Button(T.requestModalErrorNoItemCta) {
                        dismiss()
                    }
                    .buttonStyle(.bezeled)
                }
            )
        case ConnectPullReqestCommunicationError.sendPasswordDataFailure:
            ConnectCommunicationContentView(
                iconColor: .warning500,
                title: Label(T.requestModalErrorSendDataTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                description: Text(T.requestModalErrorSendDataSubtitle.localizedKey),
                actions: {
                    Button(T.requestModalErrorGenericCta) {
                        dismiss()
                    }
                    .buttonStyle(.bezeled)
                }
            )
        case URLError.notConnectedToInternet:
            ConnectCommunicationContentView(
                iconColor: .danger500,
                title: Label(T.connectModalErrorNoInternetTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                description: Text(T.connectModalErrorNoInternetSubtitle.localizedKey),
                actions: {
                    Button(T.requestModalErrorGenericCta) {
                        dismiss()
                    }
                    .buttonStyle(.bezeled)
                }
            )
        default:
            ConnectCommunicationContentView(
                iconColor: .danger500,
                title: Label(T.requestModalErrorGenericTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                description: Text(T.requestModalErrorGenericSubtitle.localizedKey),
                actions: {
                    Button(T.requestModalErrorGenericCta) {
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
            title: Label(T.requestModalErrorItemsLimitTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
            description: Text(T.requestModalErrorItemsLimitSubtitle(limit).localizedKey),
            actions: {
                Button(T.requestModalErrorItemsLimitCta.localizedKey) {
                    dismiss()
                    presenter.onContinue()
                }
                .buttonStyle(.bezeled)
            }
        )
    }
}
