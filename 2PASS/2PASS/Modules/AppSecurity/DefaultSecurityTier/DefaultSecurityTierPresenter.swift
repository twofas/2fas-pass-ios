// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

@Observable
final class DefaultSecurityTierPresenter {
    
    var selected: ItemProtectionLevel {
        didSet {
            interactor.defaultSecurityTier = selected
        }
    }
    
    private let interactor: DefaultSecurityTierModuleInteracting
    
    init(interactor: DefaultSecurityTierModuleInteracting) {
        self.interactor = interactor
        self.selected = interactor.defaultSecurityTier
    }
}
