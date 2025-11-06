// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import SVGView
import Data
import CommonUI

private struct Constants {
    static let successDismissDelay = 3.0
    
    static let changeStateAnimationDuration = 0.1
}

struct ConnectCommunicationView: View {
    
    @State
    var presenter: ConnectCommunicationPresenter

    @State
    private var securityCheckFeedbackTrigger: Bool = false
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(\.dismiss)
    private var dismiss
    
    private var isPresentedSuccessToast: Binding<Bool> {
        Binding {
            presenter.state.isSuccess
        } set: { _ in }
    }
    
    var body: some View {
        ConnectCommunicationSheetView(
            title: Text(T.connectConnectionHeader.localizedKey),
            identicon: presenter.identicon,
            webBrowser: presenter.webBrowser,
            onClose: { dismiss() },
            content: {
                content
            }
        )
        .sensoryFeedback(.warning, trigger: presenter.state, condition: {
            $1 == .newBrowser
        })
        .sensoryFeedback(.error, trigger: presenter.state, condition: {
            $1.isFailure
        })
        .onAppear {
            presenter.onAppear(colorScheme: colorScheme)
        }
        .onDisappear {
            presenter.onDisappear()
        }
        .onChange(of: presenter.state, { oldValue, newValue in
            if case .finish(.success) = newValue {
                dismiss()
            }
        })
        .toast(Text(T.connectConnectionSuccessTitle.localizedKey), isPresented: isPresentedSuccessToast, style: .success)
        .interactiveDismissDisabled(presenter.interactiveDismissDisabled)
    }
    
    private var content: some View {
        ZStack {
            switch presenter.state {
            case .newBrowser:
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(T.connectConnectionSecurityCheckTitle.localizedKey, image: .customExclamationmarkShieldFill),
                    description: Text(T.connectConnectionSecurityCheckDescription.localizedKey),
                    actions: {
                        HStack(spacing: Spacing.m) {
                            Button(T.connectConnectionSecurityCheckAcceptCta.localizedKey) {
                                presenter.onProceed()
                            }
                            .buttonStyle(.bezeledGray)
                            
                            Button(T.commonCancel.localizedKey) {
                                dismiss()
                            }
                            .buttonStyle(.bezeled)
                        }
                    }
                )
            
            case .limitReached:
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(T.connectModalErrorExtensionsLimitTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(T.connectModalErrorExtensionsLimitSubtitle.localizedKey),
                    actions: {
                        Button(T.connectModalErrorExtensionsLimitCta.localizedKey) {
                            dismiss()
                            presenter.onUpgradePlan()
                        }
                        .buttonStyle(.filled)
                    }
                )
            
            case .connecting, .finish(.success):
                ProgressView(value: presenter.progress) {
                    Text(T.connectConnectionConnecting.localizedKey)
                }
                .progressViewStyle(.circle)
                .frame(maxWidth: .infinity)

            case .finish(.failure(ConnectWebSocketError.browserExtensionUpdateRequired)):
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(T.connectModalErrorBrowserExtensionUpdateRequiredTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(T.connectModalErrorBrowserExtensionUpdateRequiredSubtitle.localizedKey),
                    actions: {
                        Button(T.commonClose.localizedKey) {
                            dismiss()
                            presenter.onScanAgain()
                        }
                        .buttonStyle(.filled)
                    }
                )
                
            case .finish(.failure(ConnectWebSocketError.appUpdateRequired)):
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(T.connectModalErrorAppUpdateRequiredTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(T.connectModalErrorAppUpdateRequiredSubtitle.localizedKey),
                    actions: {
                        HStack(spacing: Spacing.m) {
                            Button(T.commonClose.localizedKey) {
                                dismiss()
                                presenter.onScanAgain()
                            }
                            .buttonStyle(.bezeledGray)
                            
                            Button(T.connectModalErrorAppUpdateRequiredCta.localizedKey) {
                                dismiss()
                                presenter.onUpdateApp()
                            }
                            .buttonStyle(.filled)
                        }
                    }
                )

            case .finish(.failure(URLError.notConnectedToInternet)):
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(T.connectModalErrorNoInternetTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(T.connectModalErrorNoInternetSubtitle.localizedKey),
                    actions: {
                        Button(T.connectConnectionFailedCta.localizedKey) {
                            dismiss()
                            presenter.onScanAgain()
                        }
                        .buttonStyle(.filled)
                    }
                )
                
            case .finish(.failure):
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(T.connectConnectionFailedTitle.localizedKey, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(T.connectConnectionFailedDescription.localizedKey),
                    actions: {
                        Button(T.connectConnectionFailedCta.localizedKey) {
                            dismiss()
                            presenter.onScanAgain()
                        }
                        .buttonStyle(.filled)
                    }
                )
            }
        }
        .animation(.easeInOut(duration: Constants.changeStateAnimationDuration), value: presenter.state)
    }
}

#Preview {
    let session = ConnectSession(version: .v2, sessionId: "", pkPersBeHex: "", pkEpheBeHex: "", signatureHex: "")
    
    Color.white
        .sheet(isPresented: .constant(true)) {
            ConnectCommunicationRouter.buildView(session: session, onScanAgain: {})
        }
}
