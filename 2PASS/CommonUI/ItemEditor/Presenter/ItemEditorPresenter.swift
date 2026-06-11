// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftUI
import Data

@Observable
final class ItemEditorPresenter {

    enum Form {
        case login(LoginEditorFormPresenter)
        case secureNote(SecureNoteEditorFormPresenter)
        case paymentCard(PaymentCardEditorFormPresenter)
        case wifi(WiFiEditorFormPresenter)
    }

    var contentType: ItemContentType {
        switch form {
        case .login:
            return .login
        case .secureNote:
            return .secureNote
        case .paymentCard:
            return .paymentCard
        case .wifi:
            return .wifi
        }
    }

    var title: String {
        switch (contentType, isEdit) {
        case (.login, false):
            String(localized: .loginAddTitle)
        case (.login, true):
            String(localized: .loginEditTitle)
        case (.secureNote, false):
            String(localized: .secureNoteAddTitle)
        case (.secureNote, true):
            String(localized: .secureNoteEditTitle)
        case (.paymentCard, false):
            String(localized: .cardAddTitle)
        case (.paymentCard, true):
            String(localized: .cardEditTitle)
        case (.wifi, false):
            String(localized: .wifiAddTitle)
        case (.wifi, true):
            String(localized: .wifiEditTitle)
        case (.unknown, _):
            ""
        }
    }

    private(set) var form: Form

    var saveEnabled: ((Bool) -> Void)?

    var loginFormPresenter: LoginEditorFormPresenter?
    var secureNotePresenter: SecureNoteEditorFormPresenter?
    var paymentCardPresenter: PaymentCardEditorFormPresenter?
    var wifiPresenter: WiFiEditorFormPresenter?

    let allowChangeContentType: Bool

    var showRemoveItemButton: Bool {
        isEdit && interactor.changeRequest == nil
    }

    var cantSave = false

    private(set) var isEdit: Bool

    private let flowController: ItemEditorFlowControlling
    private let interactor: ItemEditorModuleInteracting
    @ObservationIgnored
    private var storageDidChangeToken: Notifications.ObservationToken?

    private var firstAppear = true

    private var currentPresenter: ItemEditorFormPresenter {
        switch form {
        case .login(let presenter):
            return presenter
        case .secureNote(let presenter):
            return presenter
        case .paymentCard(let presenter):
            return presenter
        case .wifi(let presenter):
            return presenter
        }
    }

    init(flowController: ItemEditorFlowControlling, interactor: ItemEditorModuleInteracting) {
        self.flowController = flowController
        self.interactor = interactor

        let initalData = interactor.getEditItem()
        let changeRequest = interactor.changeRequest

        let contentType = changeRequest?.contentType ?? initalData?.contentType ?? .login
        self.isEdit = initalData != nil

        if let changeRequest {
            self.allowChangeContentType = changeRequest.allowChangeContentType
        } else {
            self.allowChangeContentType = initalData == nil
        }

        switch contentType {
        case .login:
            let formPresenter = LoginEditorFormPresenter(
                interactor: interactor,
                flowController: flowController,
                initialData: initalData?.asLoginItem,
                changeRequest: interactor.changeRequest as? LoginDataChangeRequest
            )
            self.loginFormPresenter = formPresenter
            self.form = .login(formPresenter)

        case .secureNote:
            let formPresenter = SecureNoteEditorFormPresenter(
                interactor: interactor,
                flowController: flowController,
                initialData: initalData?.asSecureNote,
                changeRequest: interactor.changeRequest as? SecureNoteDataChangeRequest
            )
            self.secureNotePresenter = formPresenter
            self.form = .secureNote(formPresenter)

        case .paymentCard:
            let formPresenter = PaymentCardEditorFormPresenter(
                interactor: interactor,
                flowController: flowController,
                initialData: initalData?.asPaymentCard,
                changeRequest: interactor.changeRequest as? PaymentCardDataChangeRequest
            )
            self.paymentCardPresenter = formPresenter
            self.form = .paymentCard(formPresenter)

        case .wifi:
            let formPresenter = WiFiEditorFormPresenter(
                interactor: interactor,
                flowController: flowController,
                initialData: initalData?.asWiFi,
                changeRequest: interactor.changeRequest as? WiFiDataChangeRequest
            )
            self.wifiPresenter = formPresenter
            self.form = .wifi(formPresenter)

        case .unknown:
            fatalError("Unsupported unknown item type in Item Editor")
        }

        observeCurrentPresenterChanges()
    }

    func setContentType(_ contentType: ItemContentType) {
        withAnimation {
            self.form = form(for: contentType)
        }
    }

    func onClose() {
        flowController.close(with: .failure(.userCancelled))
    }

    func handleChangeProtectionLevel(_ value: ItemProtectionLevel) {
        currentPresenter.protectionLevel = value
    }

    func handleIconChange(_ value: PasswordIconType) {
        loginFormPresenter?.handleIconChange(value)
    }

    @MainActor
    func onAppear() {
        if firstAppear {
            updateSaveState()
            firstAppear = false
        }

        if isEdit {
            startStorageObservation()
        }
    }

    func onDisappear() {
        loginFormPresenter?.cancelFetchIcon()
    }

    @MainActor
    func onSave() {
        guard currentPresenter.canSave else {
            updateSaveState()
            return
        }

        stopStorageObservation()

        let result = currentPresenter.onSave()

        if result.isSuccess {
            flowController.close(with: result)
        } else {
            cantSave = true
            if isEdit {
                startStorageObservation()
            }
        }
    }

    func onDelete() {
        stopStorageObservation()

        guard let itemID = interactor.moveToTrash() else {
            return
        }
        flowController.close(with: .success(.deleted(itemID)))
    }

    deinit {
        stopStorageObservation()
    }
}

private extension ItemEditorPresenter {

    func form(for contentType: ItemContentType) -> Form {
        switch contentType {
        case .login:
            let presenter = {
                if let loginFormPresenter {
                    return loginFormPresenter
                } else {
                    let presenter = LoginEditorFormPresenter(interactor: interactor, flowController: flowController)
                    loginFormPresenter = presenter
                    return presenter
                }
            }()
            return .login(presenter)

        case .secureNote:
            let presenter = {
                if let secureNotePresenter {
                    return secureNotePresenter
                } else {
                    let presenter = SecureNoteEditorFormPresenter(interactor: interactor, flowController: flowController)
                    secureNotePresenter = presenter
                    return presenter
                }
            }()
            return .secureNote(presenter)

        case .paymentCard:
            let presenter = {
                if let paymentCardPresenter {
                    return paymentCardPresenter
                } else {
                    let presenter = PaymentCardEditorFormPresenter(interactor: interactor, flowController: flowController)
                    paymentCardPresenter = presenter
                    return presenter
                }
            }()
            return .paymentCard(presenter)

        case .wifi:
            let presenter = {
                if let wifiPresenter {
                    return wifiPresenter
                } else {
                    let presenter = WiFiEditorFormPresenter(interactor: interactor, flowController: flowController)
                    wifiPresenter = presenter
                    return presenter
                }
            }()
            return .wifi(presenter)

        case .unknown:
            fatalError("Unsupported unknown item type in Item Editor")
        }
    }

    func observeCurrentPresenterChanges() {
        withObservationTracking { [weak self] in
            guard let self else { return }
            self.saveEnabled?(self.currentPresenter.canSave)
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeCurrentPresenterChanges()
            }
        }
    }

    func updateSaveState() {
        saveEnabled?(currentPresenter.canSave)
    }

    @MainActor
    func startStorageObservation() {
        storageDidChangeToken?.cancel()
        storageDidChangeToken = NotificationCenter.default.addObserver(of: VaultDataDidChange.self) { [weak self] message in
            guard let self, message.affects([.items]) else { return }
            self.checkCurrentPasswordState()
        }
        checkCurrentPasswordState()
    }

    func stopStorageObservation() {
        storageDidChangeToken?.cancel()
        storageDidChangeToken = nil
    }

    func checkCurrentPasswordState() {
        DispatchQueue.main.async {
            let deleted: Bool
            switch self.interactor.checkCurrentPasswordState() {
            case .deleted: deleted = true
            case .edited: deleted = false
            case .noChange: return
            }
            // Stop watching before presenting: further notifications must not stack more alerts.
            self.stopStorageObservation()
            self.flowController.toItemChangedOnOtherDevice(deleted: deleted)
        }
    }
}
