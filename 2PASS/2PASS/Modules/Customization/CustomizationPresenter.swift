// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import SwiftUI

enum CustomizationDestination: RouterDestination {
    case defaultPasswordsListAction(picker: SettingsPicker<PasswordListAction>)
    
    var id: String {
        switch self {
        case .defaultPasswordsListAction: "defaultPasswordsListAction"
        }
    }
}

@Observable
final class CustomizationPresenter {
    
    var destination: CustomizationDestination?
    
    var deviceName: String {
        interactor.deviceName
    }
    
    var selectedDefaultActionDesctiption: String {
        PasswordListActionFormatStyle().format(selectedDefaultAction)
    }
    private var selectedDefaultAction: PasswordListAction
    
    private let interactor: CustomizationModuleInteracting
    
    init(interactor: CustomizationModuleInteracting) {
        self.interactor = interactor
        self.selectedDefaultAction = interactor.defaultPassswordListAction
    }

    func onChangeDefaultAction() {
        destination = .defaultPasswordsListAction(picker: .init(
            options: PasswordListAction.allCases,
            selected: Binding(get: {
                self.selectedDefaultAction
            }, set: { action in
                if let action {
                    self.selectedDefaultAction = action
                    self.interactor.setDefaultPassswordListAction(action)
                }
            }),
            formatter: {
                PasswordListActionFormatStyle().format($0)
            })
        )
    }
}
