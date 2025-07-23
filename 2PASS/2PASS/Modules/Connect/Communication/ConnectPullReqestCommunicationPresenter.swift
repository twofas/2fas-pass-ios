// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

enum ConnectPullReqestCommunicationError: Error {
    case sendPasswordDataFailure
}

enum ConnectPullReqestCommunicationDestination: RouterDestination {
    case addItem(changeRequest: PasswordDataChangeRequest, onClose: (SavePasswordResult) -> Void)
    case editItem(PasswordData, changeRequest: PasswordDataChangeRequest, onClose: (SavePasswordResult) -> Void)
    
    var id: String {
        switch self {
        case .addItem:
            "addItem"
        case .editItem(let passwordData, _, _):
            "editItem_\(passwordData.id)"
        }
    }
}

@Observable @MainActor
final class ConnectPullReqestCommunicationPresenter {
    
    var notification: AppNotification {
        interactor.appNotification
    }
    
    var destination: ConnectPullReqestCommunicationDestination?
    
    private(set) var progress: Float = 0.0
    private(set) var identicon: String?
    private(set) var webBrowser: WebBrowser?
    private(set) var action: ConnectAction?
    private(set) var iconContent: IconContent?
    
    private(set) var state: State = .connecting {
        didSet {
            switch state {
            case .action(.add(let changeRequest)):
                if let uri = changeRequest.uris?.first?.uri, let domain = interactor.extractDomain(from: uri) {
                    setIconContent(iconType: .domainIcon(domain), name: changeRequest.name)
                } else {
                    setIconContent(iconType: .domainIcon(nil), name: changeRequest.name)
                }
            default:
                if let passwordData = state.passwordData {
                    setIconContent(iconType: passwordData.iconType, name: passwordData.name)
                }
            }
        }
    }
    
    private let interactor: ConnectPullReqestCommunicationModuleInteracting
    
    private var actionContinuation: CheckedContinuation<ConnectContinuation, Never>?
    private var fetchingIconTask: Task<Void, Never>?
    private var connectingTask: Task<Void, Never>?
        
    init(interactor: ConnectPullReqestCommunicationModuleInteracting) {
        self.interactor = interactor
    }
    
    func onAppear(colorScheme: SwiftUI.ColorScheme) {
        switch colorScheme {
        case .dark:
            identicon = interactor.identiconSVG(colorScheme: .dark)
        default:
            identicon = interactor.identiconSVG(colorScheme: .light)
        }
        
        connect()
        
        Task {
            try await interactor.deleteAppNotification()
        }
    }
    
    func onDisappear() {
        actionContinuation?.resume(returning: (false, nil))
        actionContinuation = nil
        
        connectingTask?.cancel()
        connectingTask = nil
    }
    
    func onContinue() {
        switch state {
        case .connecting, .finish:
            break
            
        case .itemsLimitReached:
            NotificationCenter.default.post(name: .presentPaymentScreen, object: self)
            
        case .action(.passwordRequest):
            state = .connecting
            actionContinuation?.resume(returning: (true, nil))
            actionContinuation = nil
            
        case .action(.add(let changeRequest)):
            destination = .addItem(changeRequest: changeRequest, onClose: { [weak self] result in
                self?.onSavePassword(result: result)
            })
            
        case .action(.update(let passwordData, let changeRequest)):
            destination = .editItem(passwordData, changeRequest: changeRequest, onClose: { [weak self] result in
                self?.onSavePassword(result: result)
            })
            
        case .action(.delete(let passwordData)):
            interactor.deletePassword(for: passwordData.passwordID)
            
            state = .connecting
            actionContinuation?.resume(returning: (true, nil))
            actionContinuation = nil
            
            NotificationCenter.default.post(name: .connectPullReqestDidChangeNotification, object: nil)
        }
    }
    
    func onCancel() {
        actionContinuation?.resume(returning: (false, nil))
        actionContinuation = nil
    }

    private func setIconContent(iconType: PasswordIconType, name: String?) {
        switch iconType {
        case .label(labelTitle: let title, labelColor: let color):
            iconContent = .label(title, color: color)
            
        case .customIcon(let url):
            iconContent = .label(Config.defaultIconLabel(forName: name ?? ""), color: nil)
            fetchIcon(from: url, name: name ?? "")
            
        case .domainIcon:
            iconContent = .label(Config.defaultIconLabel(forName: name ?? ""), color: nil)
            
            if let url = iconType.iconURL {
                fetchIcon(from: url, name: name ?? "")
            }
        }
    }
    
    private func fetchIcon(from iconURL: URL, name: String) {
        iconContent = .loading
        
        fetchingIconTask?.cancel()
        fetchingIconTask = Task { @MainActor in
            if let imageData = try? await interactor.fetchIconImage(from: iconURL), let image = UIImage(data: imageData) {
                iconContent = .icon(image)
            } else {
                iconContent = .label(Config.defaultIconLabel(forName: name), color: nil)
            }
        }
    }
    
    private func connect() {
        connectingTask = Task {
            do {
                try await interactor.connect(
                    progress: { [weak self] progress in
                        Task { @MainActor in
                            self?.progress = progress
                        }
                    },
                    onReceiveBrowserInfo: { [weak self] webBrowser in
                        Task { @MainActor in
                            self?.webBrowser = webBrowser
                        }
                    },
                    shouldPerfromAction: { [weak self] action in
                        await withCheckedContinuation { @MainActor continuation in
                            self?.action = action
                            
                            if case .add = action, let interactor = self?.interactor, interactor.canAddItem == false {
                                self?.state = .itemsLimitReached(interactor.currentPlanItemsLimit)
                            } else {
                                self?.state = .action(action)
                            }
                            self?.actionContinuation = continuation
                        }
                    }
                )
                state = .finish(.success(()))
            } catch {
                state = .finish(.failure(error))
            }
        }
    }
    
    private func onSavePassword(result: SavePasswordResult) {
        destination = nil
        
        switch result {
        case .success(let saveResult):
            if state.isFailure {
                state = .finish(.failure(ConnectPullReqestCommunicationError.sendPasswordDataFailure))
            } else {
                state = .connecting
                actionContinuation?.resume(returning: (true, saveResult.passwordID))
                actionContinuation = nil
            }
            
            NotificationCenter.default.post(name: .connectPullReqestDidChangeNotification, object: nil)
        case .failure:
            break
        }
    }
}

extension ConnectPullReqestCommunicationPresenter {
    
    enum State: Equatable {
        case connecting
        case itemsLimitReached(Int)
        case action(ConnectAction)
        case finish(Result<Void, Error>)
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.connecting, .connecting): return true
            case (.itemsLimitReached, .itemsLimitReached): return true
            case (.action, .action): return true
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
        
        var passwordData: PasswordData? {
            switch self {
            case .action(let action):
                switch action {
                case .passwordRequest(let passwordData):
                    return passwordData
                case .update(let currentPasswordData, _):
                    return currentPasswordData
                case .add:
                    return nil
                case .delete(let passwordData):
                    return passwordData
                }
            default:
                return nil
            }
        }
    }
}
