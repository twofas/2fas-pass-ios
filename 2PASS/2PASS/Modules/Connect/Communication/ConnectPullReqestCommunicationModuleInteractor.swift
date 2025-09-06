// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import Common

protocol ConnectPullReqestCommunicationModuleInteracting: AnyObject {
    
    var currentPlanItemsLimit: Int { get }
    var canAddItem: Bool { get }
    
    var appNotification: AppNotification { get }
    
    func identiconSVG(colorScheme: ColorScheme) -> String?
    func fetchIconImage(from url: URL) async throws -> Data
    func extractDomain(from urlString: String) -> String?
    func deletePassword(for passwordID: PasswordID)
    func deleteAppNotification() async throws
    
    func connect(
        progress: @escaping (Float) -> Void,
        onReceiveBrowserInfo: @escaping (WebBrowser) -> Void,
        shouldPerfromAction: @escaping (ConnectAction) async -> ConnectContinuation
    ) async throws
}

final class ConnectPullReqestCommunicationModuleInteractor: ConnectPullReqestCommunicationModuleInteracting {
    
    let appNotification: AppNotification
    let identiconInteractor: ConnectIdenticonInteracting
    let connectInteractor: ConnectInteracting
    let fileIconInteractor: FileIconInteracting
    let uriInteractor: URIInteracting
    let passwordInteractor: PasswordInteracting
    let appNotificationsInteractor: AppNotificationsInteracting
    let paymentStatusInteractor: PaymentStatusInteracting
    
    init(appNotification: AppNotification,
         connectInteractor: ConnectInteracting,
         identiconInteractor: ConnectIdenticonInteracting,
         fileIconInteractor: FileIconInteracting,
         uriInteractor: URIInteracting,
         passwordInteractor: PasswordInteracting,
         appNotificationsInteractor: AppNotificationsInteracting,
         paymentStatusInteractor: PaymentStatusInteracting
    ) {
        self.appNotification = appNotification
        self.connectInteractor = connectInteractor
        self.identiconInteractor = identiconInteractor
        self.fileIconInteractor = fileIconInteractor
        self.uriInteractor = uriInteractor
        self.passwordInteractor = passwordInteractor
        self.appNotificationsInteractor = appNotificationsInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
    }
    
    var canAddItem: Bool {
        guard let limit = paymentStatusInteractor.entitlements.itemsLimit else {
            return true
        }
        return passwordInteractor.itemsCount < limit
    }
    
    var currentPlanItemsLimit: Int {
        paymentStatusInteractor.entitlements.itemsLimit ?? Int.max
    }
    
    func connect(
        progress: @escaping (Float) -> Void,
        onReceiveBrowserInfo: @escaping (WebBrowser) -> Void,
        shouldPerfromAction: @escaping (ConnectAction) async -> ConnectContinuation
    ) async throws {
        try await connectInteractor.connect(
            for: appNotification,
            progress: progress,
            onReceiveBrowserInfo: onReceiveBrowserInfo,
            shouldPerfromAction: shouldPerfromAction
        )
    }
    
    func identiconSVG(colorScheme: ColorScheme) -> String? {
        guard let data = Data(base64Encoded: appNotification.data.pkPersBe) else {
            return nil
        }
        return identiconInteractor.identiconSVG(fromPublicKey: data.toHEXString(), colorScheme: colorScheme)
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
    
    func extractDomain(from urlString: String) -> String? {
        uriInteractor.extractDomain(from: urlString)
    }
    
    func deletePassword(for passwordID: PasswordID) {
        passwordInteractor.markAsTrashed(for: passwordID)
        passwordInteractor.saveStorage()
    }
    
    func deleteAppNotification() async throws {
        try await appNotificationsInteractor.deleteAppNotification(appNotification)
    }
}
