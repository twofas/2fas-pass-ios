// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol ConnectCommunicationModuleInteracting: AnyObject {
    
    @MainActor
    var canAddWebBrowser: Bool { get }
    
    func identiconSVG(fromPublicKey pkPersBeHex: String, colorScheme: ColorScheme) -> String?
    
    @MainActor
    func isKnownBrowser(from session: ConnectSession) -> Bool
    
    func connect(with session: ConnectSession,
                 progress: @escaping (Float) -> Void,
                 onReceiveBrowserInfo: @escaping (WebBrowser) -> Void) async throws
}

final class ConnectCommunicationModuleInteractor: ConnectCommunicationModuleInteracting {
    
    private let connectInteractor: ConnectInteracting
    private let securityIconInteractor: ConnectIdenticonInteracting
    private let webBrowsersInteractor: WebBrowsersInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting
    
    init(connectInteractor: ConnectInteracting,
         securityIconInteractor: ConnectIdenticonInteracting,
         webBrowsersInteractor: WebBrowsersInteracting,
         paymentStatusInteractor: PaymentStatusInteracting
    ) {
        self.connectInteractor = connectInteractor
        self.securityIconInteractor = securityIconInteractor
        self.webBrowsersInteractor = webBrowsersInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
    }
    
    @MainActor
    var canAddWebBrowser: Bool {
        guard let limit = paymentStatusInteractor.entitlements.connectedBrowsersLimit else {
            return true
        }
        
        return webBrowsersInteractor.list().count < limit
    }
    
    func identiconSVG(fromPublicKey pkPersBeHex: String, colorScheme: ColorScheme) -> String? {
        securityIconInteractor.identiconSVG(fromPublicKey: pkPersBeHex, colorScheme: colorScheme)
    }
    
    func isKnownBrowser(from session: ConnectSession) -> Bool {
        connectInteractor.isKnownBrowser(from: session)
    }
    
    func connect(with session: ConnectSession, progress: @escaping (Float) -> Void, onReceiveBrowserInfo: @escaping (WebBrowser) -> Void) async throws {
        try await connectInteractor.connect(with: session, progress: progress, onReceiveBrowserInfo: onReceiveBrowserInfo)
    }
}
