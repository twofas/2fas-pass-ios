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
        ConnectCommunicationSheetView(title: Text(T.requestModalHeaderTitle), identicon: presenter.identicon, webBrowser: presenter.webBrowser) {
            ZStack {
                switch presenter.state {
                case .connecting, .finish(.success):
                    progressView

                case .action(.passwordRequest(let item)):
                    passwordRequestView(item: item)
                    
                case .action(.update(let item, _)):
                    updatePasswordView(item: item)
                
                case .action(.add(let changeRequest)):
                   addPasswordView(changeRequest: changeRequest)
                    
                case .action(.delete(let passwordData)):
                    deletePasswordView(item: passwordData)
                    
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
        case .passwordRequest:
            Text(T.requestModalToastSuccessPasswordRequest.localizedKey)
        case .update:
            Text(T.requestModalToastSuccessUpdateLogin.localizedKey)
        case .add:
            Text(T.requestModalToastSuccessAddLogin.localizedKey)
        case .delete:
            Text(T.requestModalToastSuccessDeleteLogin.localizedKey)
        case nil:
            Text("")
        }
    }
    
    private var progressView: some View {
        ProgressView(value: presenter.progress) {
            Text(T.connectConnectionConnecting.localizedKey)
        }
        .progressViewStyle(.circle)
        .frame(maxWidth: .infinity)
    }
    
    private func passwordRequestView(item: PasswordData) -> some View {
        ConnectPullReqestContentView(
            title: Text(T.requestModalPasswordRequestTitle.localizedKey),
            description: Text(T.requestModalPasswordRequestSubtitle.localizedKey),
            item: .init(name: item.name ?? "", username: item.username, iconContent: presenter.iconContent),
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
    
    private func addPasswordView(changeRequest: PasswordDataChangeRequest) -> some View {
        ConnectPullReqestContentView(
            title: Text(T.requestModalNewItemTitle.localizedKey),
            description: Text(T.requestModalNewItemSubtitle.localizedKey),
            item: .init(name: changeRequest.name ?? "", username: changeRequest.username, iconContent: presenter.iconContent),
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
    
    private func updatePasswordView(item: PasswordData) -> some View {
        ConnectPullReqestContentView(
            title: Text(T.requestModalUpdateItemTitle.localizedKey),
            description: Text(T.requestModalUpdateItemSubtitle.localizedKey),
            item: .init(name: item.name ?? "", username: item.username, iconContent: presenter.iconContent),
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
    
    private func deletePasswordView(item: PasswordData) -> some View {
        ConnectPullReqestContentView(
            title: Text(T.requestModalRemoveItemTitle.localizedKey),
            description: Text(T.requestModalRemoveItemSubtitle.localizedKey),
            item: .init(name: item.name ?? "", username: item.username, iconContent: presenter.iconContent),
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
