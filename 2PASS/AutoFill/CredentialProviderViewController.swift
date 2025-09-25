// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import SwiftUI
import Data
import CommonUI
import Common

final class CredentialProviderViewController: ASCredentialProviderViewController {
    private let startupInteractor = InteractorFactory.shared.startupInteractor()
    var presenter: AutoFillRootPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "MainBackgroundColor")
        
        Task { @MainActor in
            startupInteractor.initialize()
            addRootView()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        presenter.viewDidAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.viewWillDisappear()
        LogSave()
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        presenter.prepare(for: serviceIdentifiers)
    }
    
    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        presenter.provide(for: credentialRequest)
    }
    
    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        presenter.provideWithoutUserInteraction(for: credentialRequest)
    }
    
    override func prepareInterfaceForUserChoosingTextToInsert() {
        presenter.prepareForTextToInsert()
    }
}

private extension CredentialProviderViewController {
    func addRootView() {
        presenter = AutoFillRootPresenter(
            extensionContext: extensionContext,
            interactor: ModuleInteractorFactory.shared.autoFillInteractor()
        )
        
        let hostingController = UIHostingController(rootView: AutoFillRootView(presenter: presenter))
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.pinToParent()
        hostingController.didMove(toParent: self)
    }
}
