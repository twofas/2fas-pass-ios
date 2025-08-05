// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol PasswordsFlowControllerParent: AnyObject {
    func passwordsToViewPassword(passwordID: PasswordID)
    func selectPassword(passwordID: PasswordID)
    func cancel()
    func toQuickSetup()
    func toPremiumPlanPrompt(itemsLimit: Int)
    
    @MainActor
    func toConfirmDelete() async -> Bool
}

protocol PasswordsFlowControlling: AnyObject {
    func toAddPassword()
    func toEditPassword(passwordID: PasswordID)
    func toViewPassword(passwordID: PasswordID)
    func toURI(_ selectedURI: URL)
    
    func selectPassword(passwordID: PasswordID)
    func cancel()
    
    func toQuickSetup()
    func toPremiumPlanPrompt(itemsLimit: Int)

    @MainActor
    func toConfirmDelete() async -> Bool
}

public final class PasswordsFlowController: FlowController {
    private weak var parent: PasswordsFlowControllerParent?
    private var autoFillEnvironment: AutoFillEnvironment?
    
    public static func setAsRoot(
        on navigationController: UINavigationController,
        parent: PasswordsFlowControllerParent,
        autoFillEnvironment: AutoFillEnvironment? = nil
    ) {
        let view = PasswordsViewController()
        let flowController = PasswordsFlowController(viewController: view)
        flowController.parent = parent
        flowController.autoFillEnvironment = autoFillEnvironment
        
        let interactor = ModuleInteractorFactory.shared.passwordInteractor()
        
        let presenter = PasswordsPresenter(
            autoFillEnvironment: autoFillEnvironment,
            flowController: flowController,
            interactor: interactor
        )
        view.presenter = presenter
        presenter.view = view

        navigationController.setViewControllers([view], animated: false)
    }
}

extension PasswordsFlowController: PasswordsFlowControlling {
    func toAddPassword() {
        let changeRequest: PasswordDataChangeRequest?
        if let serviceIdentifiers = autoFillEnvironment?.serviceIdentifiers {
            changeRequest = PasswordDataChangeRequest(uris: serviceIdentifiers.map { .init(uri: $0, match: .domain)} )
        } else {
            changeRequest = nil
        }
        
        AddPasswordNavigationFlowController.present(
            on: viewController,
            parent: self,
            editPasswordID: nil,
            changeRequest: changeRequest
        )
    }
    
    func toEditPassword(passwordID: PasswordID) {
        AddPasswordNavigationFlowController.present(
            on: viewController,
            parent: self,
            editPasswordID: passwordID
        )
    }
    
    func toViewPassword(passwordID: PasswordID) {
        parent?.passwordsToViewPassword(passwordID: passwordID)
    }
    
    func toURI(_ selectedURI: URL) {
        UIApplication.shared.openInBrowser(selectedURI)
    }
    
    func selectPassword(passwordID: PasswordID) {
        parent?.selectPassword(passwordID: passwordID)
    }
    
    func cancel() {
        parent?.cancel()
    }
    
    func toQuickSetup() {
        parent?.toQuickSetup()
    }
    
    @MainActor
    func toConfirmDelete() async -> Bool {
        await parent?.toConfirmDelete() ?? false
    }
    
    func toPremiumPlanPrompt(itemsLimit: Int) {
        parent?.toPremiumPlanPrompt(itemsLimit: itemsLimit)
    }
}

extension PasswordsFlowController {
    var viewController: PasswordsViewController { _viewController as! PasswordsViewController }
}

extension PasswordsFlowController: AddPasswordNavigationFlowControllerParent {
    
    func closeAddPassword(with result: SavePasswordResult) {
        viewController.presenter.handleRefresh()
        viewController.dismiss(animated: true)
    }
}
