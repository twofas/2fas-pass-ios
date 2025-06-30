// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

enum GenerateSecretKeyRouteDestination: Identifiable {
    case halfway
    
    var id: String {
        switch self {
        case .halfway:
            return "halfway"
        }
    }
}

@Observable
final class GenerateSecretKeyPresenter {
    
    private let interactor: GenerateSecretKeyModuleInteracting
    
    var destination: GenerateSecretKeyRouteDestination?
            
    private(set) var isFinished: Bool = false
    
    init(interactor: GenerateSecretKeyModuleInteracting) {
        self.interactor = interactor
    }
    
    func onAppear() {
        if isFinished == false {
            interactor.setupEncryptionElements()
        }
    }
    
    func onFinishGenerating() {
        isFinished = true
    }
    
    func onContinueTap() {
        destination = .halfway
    }
}
