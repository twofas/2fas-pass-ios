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

    let itemID: ItemID
    private let flowController: ItemDetailFlowControlling
    private let interactor: ItemDetailModuleInteracting
    private let toastPresenter: ToastPresenter
    private let autoFillEnvironment: AutoFillEnvironment?
    @ObservationIgnored
    private var storageDidChangeToken: Notifications.ObservationToken?

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
        storageDidChangeToken?.cancel()
    }
}

extension ItemDetailPresenter {

    @MainActor
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

        // Register synchronously so a save posted before the observer is live isn't dropped.
        storageDidChangeToken?.cancel()
        storageDidChangeToken = NotificationCenter.default.addObserver(of: VaultDataDidChange.self) { [weak self] message in
            guard let self, message.affects([.items, .tags]) else { return }
            self.refreshState()
        }
    }

    func onDisappear() {
        storageDidChangeToken?.cancel()
        storageDidChangeToken = nil
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
