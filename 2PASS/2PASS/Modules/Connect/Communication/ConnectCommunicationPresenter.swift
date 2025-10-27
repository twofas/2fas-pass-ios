// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import Common
import SwiftUI

private struct Constants {
    static let showSecurityCheckDelay = Duration.milliseconds(400)
    static let showLimitReachedDelay = Duration.milliseconds(400)
}

@Observable @MainActor
final class ConnectCommunicationPresenter {
        
    let session: ConnectSession
    let onScanAgain: Callback
    
    private(set) var progress: Float = 0.0
    private(set) var identicon: String?
    private(set) var webBrowser: WebBrowser?
    
    private let interactor: ConnectCommunicationModuleInteracting
    
    var interactiveDismissDisabled: Bool {
        state == .connecting || state == .newBrowser
    }
    
    private(set) var state: State = .connecting
    
    private var currentTask: Task<Void, Never>?
    
    init(session: ConnectSession, interactor: ConnectCommunicationModuleInteracting, onScanAgain: @escaping Callback) {
        self.session = session
        self.interactor = interactor
        self.onScanAgain = onScanAgain
    }
    
    func onAppear(colorScheme: SwiftUI.ColorScheme) {
        switch colorScheme {
        case .dark:
            identicon = interactor.identiconSVG(fromPublicKey: session.pkPersBeHex, colorScheme: .dark)
        default:
            identicon = interactor.identiconSVG(fromPublicKey: session.pkPersBeHex, colorScheme: .light)
        }
        
        guard interactor.isKnownBrowser(from: session) else {
            if interactor.canAddWebBrowser {
                Task {
                    try await Task.sleep(for: Constants.showSecurityCheckDelay)
                    state = .newBrowser
                }
            } else {
                Task {
                    try await Task.sleep(for: Constants.showLimitReachedDelay)
                    state = .limitReached
                }
            }
            return
        }
        
        connect()
    }
    
    func onProceed() {
        connect()
    }
    
    func onDisappear() {
        currentTask?.cancel()
    }
    
    func onUpgradePlan() {
        Task { @MainActor in
            try await Task.sleep(for: .milliseconds(700))
            NotificationCenter.default.post(name: .presentPaymentScreen, object: self)
        }
    }
    
    func onUpdateApp() {
        UIApplication.shared.open(Config.appStoreURL)
    }
    
    private func connect() {
        state = .connecting
        currentTask = Task {
            do {
                try await interactor.connect(with: session, progress: { progress in
                    Task { @MainActor in
                        self.progress = progress
                    }
                }, onReceiveBrowserInfo: { [weak self] webBrowser in
                    Task { @MainActor in
                        self?.webBrowser = webBrowser
                    }
                })
                state = .finish(.success(()))
            } catch {
                state = .finish(.failure(error))
            }
        }
    }
}

extension ConnectCommunicationPresenter {
    
    enum State: Equatable {
        case connecting
        case limitReached
        case newBrowser
        case finish(Result<Void, Error>)
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.connecting, .connecting): return true
            case (.newBrowser, .newBrowser): return true
            case (.finish, .finish): return true
            default: return false
            }
        }
        
        var isSuccess: Bool {
            if case .finish(.success) = self {
                return true
            } else {
                return false
            }
        }
        
        var isFailure: Bool {
            if case .finish(.failure) = self {
                return true
            } else {
                return false
            }
        }
    }
}
