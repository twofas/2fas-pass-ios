// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import AuthenticationServices

struct AutoFillPasswordsListView: UIViewControllerRepresentable {
    
    let context: ASCredentialProviderExtensionContext
    let serviceIdentifiers: [ASCredentialServiceIdentifier]
    let isTextToInsert: Bool
    
    func makeUIViewController(context: Context) -> UINavigationController {
        AutofillPasswordsNavigationFlowController.setAsRoot(parent: context.coordinator, serviceIdentifiers: serviceIdentifiers.map { $0.identifier }, isTextToInsert: isTextToInsert)
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, interactor: ModuleInteractorFactory.shared.autoFillInteractor())
    }
    
    class Coordinator: AutofillPasswordsNavigationFlowControllerParent {
        let parent: AutoFillPasswordsListView
        let interactor: AutoFillModuleInteracting

        init(parent: AutoFillPasswordsListView, interactor: AutoFillModuleInteracting) {
            self.parent = parent
            self.interactor = interactor
        }
        
        func selectPassword(itemID: ItemID) {
            guard let credential = interactor.credential(for: itemID) else {
                return
            }
            parent.context.completeRequest(withSelectedCredential: credential)
        }
        
        @available(iOS 18.0, *)
        func textToInsert(_ text: String) {
            Task { @MainActor in
                await parent.context.completeRequest(withTextToInsert: text)
            }
        }
        
        func cancel() {
            parent.context.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
        }
    }
}
