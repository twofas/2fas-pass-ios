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

    var tags: [ItemTagData] {
        formPresenter?.tags ?? []
    }

    private let itemID: ItemID
    private let flowController: ItemDetailFlowControlling
    private let interactor: ItemDetailModuleInteracting
    private let toastPresenter: ToastPresenter
    private let autoFillEnvironment: AutoFillEnvironment?
    /// Consumer of `interactor.syncDidApplyRemoteChanges()` — spawned in `onAppear`, cancelled
    /// in `onDisappear`, so the subscription is alive only while the view is on screen.
    /// `@ObservationIgnored` because the handle is internal lifecycle plumbing, not observable
    /// UI state.
    @ObservationIgnored
    private var syncDidApplyRemoteChangesTask: Task<Void, Never>?

    enum Form {
        case login(LoginDetailFormPresenter)
        case secureNote(SecureNoteFormPresenter)
        case paymentCard(PaymentCardDetailFormPresenter)
        case wifi(WiFiDetailFormPresenter)
    }

    private(set) var form: Form?

    private var formPresenter: ItemDetailFormPresenter? {
        switch form {
        case .login(let presenter):
            return presenter
        case .secureNote(let presenter):
            return presenter
        case .paymentCard(let presenter):
            return presenter
        case .wifi(let presenter):
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
        self.toastPresenter = .shared
        self.autoFillEnvironment = autoFillEnvironment
    }

    deinit {
        // Safety net for the rare case where `onDisappear` doesn't fire.
        syncDidApplyRemoteChangesTask?.cancel()
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
        case .paymentCard(let item):
            form = .paymentCard(
                PaymentCardDetailFormPresenter(item: item, configuration: configuration)
            )
        case .wifi(let item):
            form = .wifi(
                WiFiDetailFormPresenter(item: item, configuration: configuration)
            )
        case .raw:
            fatalError("Unsupported content type")
        }

        syncDidApplyRemoteChangesTask?.cancel()
        syncDidApplyRemoteChangesTask = Task { [weak self] in
            guard let stream = self?.interactor.syncDidApplyRemoteChanges() else { return }
            for await _ in stream {
                self?.refreshState()
            }
        }
    }

    func onDisappear() {
        syncDidApplyRemoteChangesTask?.cancel()
        syncDidApplyRemoteChangesTask = nil
    }

    func onEdit() {
        flowController.toEdit(itemID)
    }

    func onShareLink() {
        flowController.toShareLink(itemID)
    }
}

private extension ItemDetailPresenter {

    func refreshState() {
        Task { @MainActor in
            formPresenter?.reload()
        }
    }
}
