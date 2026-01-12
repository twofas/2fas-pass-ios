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
            title: Text(.connectConnectionHeader),
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
            UIApplication.shared.isIdleTimerDisabled = true
            presenter.onAppear(colorScheme: colorScheme)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            presenter.onDisappear()
        }
        .onChange(of: presenter.state, { oldValue, newValue in
            if case .finish(.success) = newValue {
                dismiss()
            }
        })
        .toast(Text(.connectConnectionSuccessTitle), isPresented: isPresentedSuccessToast, style: .success)
        .interactiveDismissDisabled(presenter.interactiveDismissDisabled)
    }
    
    private var content: some View {
        ZStack {
            switch presenter.state {
            case .newBrowser:
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(.connectConnectionSecurityCheckTitle, image: .customExclamationmarkShieldFill),
                    description: Text(.connectConnectionSecurityCheckDescription),
                    actions: {
                        HStack(spacing: Spacing.m) {
                            Button(.connectConnectionSecurityCheckAcceptCta) {
                                presenter.onProceed()
                            }
                            .buttonStyle(.bezeledGray)
                            
                            Button(.commonCancel) {
                                dismiss()
                            }
                            .buttonStyle(.bezeled)
                        }
                    }
                )
            
            case .limitReached:
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(.connectModalErrorExtensionsLimitTitle, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(.connectModalErrorExtensionsLimitSubtitle),
                    actions: {
                        Button(.connectModalErrorExtensionsLimitCta) {
                            dismiss()
                            presenter.onUpgradePlan()
                        }
                        .buttonStyle(.filled)
                    }
                )
            
            case .connecting, .finish(.success):
                ProgressView(value: presenter.progress) {
                    Text(.connectConnectionConnecting)
                }
                .progressViewStyle(.circle)
                .frame(maxWidth: .infinity)

            case .finish(.failure(ConnectWebSocketError.browserExtensionUpdateRequired)):
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(.connectModalErrorBrowserExtensionUpdateRequiredTitle, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(.connectModalErrorBrowserExtensionUpdateRequiredSubtitle),
                    actions: {
                        Button(.commonClose) {
                            dismiss()
                            presenter.onScanAgain()
                        }
                        .buttonStyle(.filled)
                    }
                )
                
            case .finish(.failure(ConnectWebSocketError.appUpdateRequired)):
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(.connectModalErrorAppUpdateRequiredTitle, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(.connectModalErrorAppUpdateRequiredSubtitle),
                    actions: {
                        HStack(spacing: Spacing.m) {
                            Button(.commonClose) {
                                dismiss()
                                presenter.onScanAgain()
                            }
                            .buttonStyle(.bezeledGray)
                            
                            Button(.connectModalErrorAppUpdateRequiredCta) {
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
                    title: Label(.connectModalErrorNoInternetTitle, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(.connectModalErrorNoInternetSubtitle),
                    actions: {
                        Button(.connectConnectionFailedCta) {
                            dismiss()
                            presenter.onScanAgain()
                        }
                        .buttonStyle(.filled)
                    }
                )
                
            case .finish(.failure):
                ConnectCommunicationContentView(
                    iconColor: .danger500,
                    title: Label(.connectConnectionFailedTitle, systemImage: "exclamationmark.triangle.fill"),
                    description: Text(.connectConnectionFailedDescription),
                    actions: {
                        Button(.connectConnectionFailedCta) {
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
