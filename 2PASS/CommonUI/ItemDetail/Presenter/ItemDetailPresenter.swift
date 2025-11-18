// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data
import SwiftUI

@Observable
final class ItemDetailPresenter {
    
    var createdAt: String? {
        formPresenter?.createdAt
    }
    
    var modifiedAt: String? {
        formPresenter?.modifiedAt
    }
    
    private let itemID: ItemID
    private let flowController: ItemDetailFlowControlling
    private let interactor: ItemDetailModuleInteracting
    private let notificationCenter: NotificationCenter
    private let toastPresenter: ToastPresenter
    private let autoFillEnvironment: AutoFillEnvironment?
    
    enum Form {
        case login(LoginDetailFormPresenter)
        case secureNote(SecureNoteFormPresenter)
    }
    
    private(set) var form: Form?

    private var formPresenter: ItemDetailFormPresenter? {
        switch form {
        case .login(let presenter):
            return presenter
        case .secureNote(let presenter):
            return presenter
        case nil:
            return nil
        }
    }
    
    init(
        itemID: ItemID,
        flowController: ItemDetailFlowControlling,
        interactor: ItemDetailModuleInteracting,
        autoFillEnvironment: AutoFillEnvironment? = nil
    ) {
        self.itemID = itemID
        self.flowController = flowController
        self.interactor = interactor
        self.notificationCenter = .default
        self.toastPresenter = .shared
        self.autoFillEnvironment = autoFillEnvironment
        
        notificationCenter.addObserver(self, selector: #selector(syncFinished), name: .webDAVStateChange, object: nil)
        notificationCenter.addObserver(self, selector: #selector(iCloudSyncFinished), name: .cloudStateChanged, object: nil)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension ItemDetailPresenter {
    
    func onAppear() {
        guard let item = interactor.fetchItem(for: itemID) else {
            flowController.close()
            return
        }
        
        let configuration = ItemDetailFormConfiguration(
            flowController: flowController,
            interactor: interactor,
            toastPresenter: toastPresenter,
            autoFillEnvironment: autoFillEnvironment
        )
        
        switch item {
        case .login(let item):
            form = .login(
                LoginDetailFormPresenter(item: item, configuration: configuration)
            )
        case .secureNote(let item):
            form = .secureNote(
                SecureNoteFormPresenter(item: item, configuration: configuration)
            )
        case .raw:
            fatalError("Unsupported content type")
        }
    }

    func onEdit() {
        flowController.toEdit(itemID)
    }
}

private extension ItemDetailPresenter {
    
    @objc
    func syncFinished(_ event: Notification) {
        guard let e = event.userInfo?[Notification.webDAVState] as? WebDAVState, e == .synced else {
            return
        }
        refreshState()
    }
    
    @objc
    func iCloudSyncFinished() {
        refreshState()
    }
    
    func refreshState() {
        Task { @MainActor in
            formPresenter?.reload()
        }
    }
}
