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
        case card(CardEditorFormPresenter)
    }

    var contentType: ItemContentType {
        switch form {
        case .login:
            return .login
        case .secureNote:
            return .secureNote
        case .card:
            return .card
        }
    }

    var title: String {
        switch (contentType, isEdit) {
        case (.login, false):
            T.loginAddTitle
        case (.login, true):
            T.loginEditTitle
        case (.secureNote, false):
            T.secureNoteAddTitle
        case (.secureNote, true):
            T.secureNoteEditTitle
        case (.card, false):
            T.cardAddTitle
        case (.card, true):
            T.cardEditTitle
        case (.unknown, _):
            ""
        }
    }
    
    private(set) var form: Form
    
    var saveEnabled: ((Bool) -> Void)?
    
    var loginFormPresenter: LoginEditorFormPresenter?
    var secureNotePresenter: SecureNoteEditorFormPresenter?
    var cardPresenter: CardEditorFormPresenter?
    
    let allowChangeContentType: Bool
    
    var showRemoveItemButton: Bool {
        isEdit && interactor.changeRequest == nil
    }
    
    var cantSave = false

    private(set) var isEdit: Bool
    
    var passwordWasEdited = false
    var passwordWasDeleted = false

    private let flowController: ItemEditorFlowControlling
    private let interactor: ItemEditorModuleInteracting
    private let notificationCenter: NotificationCenter
    
    private var firstAppear = true
    
    private var currentPresenter: ItemEditorFormPresenter {
        switch form {
        case .login(let presenter):
            return presenter
        case .secureNote(let presenter):
            return presenter
        case .card(let presenter):
            return presenter
        }
    }
    
    init(flowController: ItemEditorFlowControlling, interactor: ItemEditorModuleInteracting) {
        self.flowController = flowController
        self.interactor = interactor
        self.notificationCenter = .default
        
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

        case .card:
            let formPresenter = CardEditorFormPresenter(
                interactor: interactor,
                flowController: flowController,
                initialData: initalData?.asCard,
                changeRequest: interactor.changeRequest as? CardDataChangeRequest
            )
            self.cardPresenter = formPresenter
            self.form = .card(formPresenter)

        case .unknown:
            fatalError("Unsupported unknown item type in Item Editor")
        }
        
        if initalData != nil {
            notificationCenter.addObserver(self, selector: #selector(syncFinished), name: .webDAVStateChange, object: nil)
            notificationCenter.addObserver(self, selector: #selector(iCloudSyncFinished), name: .cloudStateChanged, object: nil)
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
    
    func onAppear() {
        guard firstAppear else {
            return
        }
        updateSaveState()
        firstAppear = false
    }
    
    func onDisappear() {
        loginFormPresenter?.cancelFetchIcon()
    }
    
    func onSave() {
        let result = currentPresenter.onSave()
        
        if result.isSuccess {
            flowController.close(with: result)
        } else {
            cantSave = true
        }
    }
    
    func onDelete() {
        guard let itemID = interactor.moveToTrash() else {
            return
        }
        flowController.close(with: .success(.deleted(itemID)))
    }
    
    deinit {
        notificationCenter.removeObserver(self)
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

        case .card:
            let presenter = {
                if let cardPresenter {
                    return cardPresenter
                } else {
                    let presenter = CardEditorFormPresenter(interactor: interactor, flowController: flowController)
                    cardPresenter = presenter
                    return presenter
                }
            }()
            return .card(presenter)

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
        saveEnabled?(!currentPresenter.canSave)
    }

    @objc
    func syncFinished(_ event: Notification) {
        guard let e = event.userInfo?[Notification.webDAVState] as? WebDAVState, e == .synced else {
            return
        }
        checkCurrentPasswordState()
    }
    
    @objc
    func iCloudSyncFinished() {
        checkCurrentPasswordState()
    }
    
    func checkCurrentPasswordState() {
        DispatchQueue.main.async {
            switch self.interactor.checkCurrentPasswordState() {
            case .deleted: self.passwordWasDeleted = true
            case .edited: self.passwordWasEdited = true
            case .noChange: break
            }
        }
    }
}
