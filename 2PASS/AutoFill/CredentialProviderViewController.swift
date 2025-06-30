// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import SwiftUI
import Data
import CommonUI

final class CredentialProviderViewController: ASCredentialProviderViewController {

    var presenter: AutoFillRootPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "MainBackgroundColor")
        
        let startup = InteractorFactory.shared.startupInteractor()
        startup.initialize()
        let startupResult = startup.start()
        addRootView(for: startupResult)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        presenter.startBiometryIfAvailable()
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
    
    func addRootView(for startupResult: StartupInteractorStartResult) {
        presenter = AutoFillRootPresenter(
            extensionContext: extensionContext,
            startupResult: startupResult,
            interactor: ModuleInteractorFactory.shared.autoFillInteractor()
        )
        
        let hostingController = UIHostingController(rootView: AutoFillRootView(presenter: presenter))
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.pinToParent()
        hostingController.didMove(toParent: self)
    }
}
