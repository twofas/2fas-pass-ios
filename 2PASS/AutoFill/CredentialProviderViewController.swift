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
    private let interactor = ModuleInteractorFactory.shared.autoFillInteractor()
    var presenter: AutoFillRootPresenter!
    private var screenCaptureExpirationTimer: Timer?

    private lazy var screenCaptureBlockHostingController: UIHostingController<ScreenCaptureBlockView> = {
        let controller = UIHostingController(rootView: ScreenCaptureBlockView())
        controller.view.isHidden = true
        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        Task { @MainActor in
            startupInteractor.initialize()
            addRootView()
            addScreenCaptureBlockView()
            observeSceneCaptureState()
            updateCaptureState()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        presenter.viewDidAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.viewWillDisappear()
        screenCaptureExpirationTimer?.invalidate()
        screenCaptureExpirationTimer = nil
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
    
    @available(iOS 26.2, *)
    override func performWithoutUserInteraction(generatePasswordsRequest: ASGeneratePasswordsRequest) {
        presenter.generatePasswordWithoutUserInteraction()
    }
    
    @available(iOS 26.2, *)
    override func prepareInterface(for generatePasswordsRequest: ASGeneratePasswordsRequest) {
        presenter.prepareForGeneratePassword(generatePasswordsRequest)
    }

    @available(iOS 26.2, *)
    override func performWithoutUserInteractionIfPossible(savePasswordRequest: ASSavePasswordRequest) {
        presenter.savePasswordWithoutUserInteraction(savePasswordRequest)
    }

    @available(iOS 26.2, *)
    override func prepareInterface(for savePasswordRequest: ASSavePasswordRequest) {
        presenter.prepareForSavePassword(savePasswordRequest)
    }
}

private extension CredentialProviderViewController {
    func addRootView() {
        presenter = AutoFillRootPresenter(
            extensionContext: extensionContext,
            interactor: interactor
        )

        let hostingController = UIHostingController(rootView: AutoFillRootView(presenter: presenter))
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.pinToParent()
        hostingController.didMove(toParent: self)
    }

    func addScreenCaptureBlockView() {
        addChild(screenCaptureBlockHostingController)
        view.addSubview(screenCaptureBlockHostingController.view)
        screenCaptureBlockHostingController.view.pinToParent()
        screenCaptureBlockHostingController.didMove(toParent: self)
    }

    func observeSceneCaptureState() {
        registerForTraitChanges([UITraitSceneCaptureState.self]) { (viewController: Self, _) in
            viewController.updateCaptureState()
        }
    }

    func updateCaptureState() {
        scheduleScreenCaptureExpirationTimer()
        let shouldBlock = traitCollection.sceneCaptureState == .active && !interactor.isScreenCaptureAllowed
        screenCaptureBlockHostingController.view.isHidden = !shouldBlock
    }

    func scheduleScreenCaptureExpirationTimer() {
        screenCaptureExpirationTimer?.invalidate()
        screenCaptureExpirationTimer = nil

        guard let expiration = interactor.screenCaptureAllowedUntil else { return }
        let remaining = expiration.timeIntervalSinceNow
        guard remaining > 0 else { return }

        screenCaptureExpirationTimer = Timer.scheduledTimer(
            withTimeInterval: remaining,
            repeats: false
        ) { [weak self] _ in
            self?.updateCaptureState()
        }
    }
}
