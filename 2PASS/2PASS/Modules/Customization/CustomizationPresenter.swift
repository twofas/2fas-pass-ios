// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import SwiftUI

enum CustomizationDestination: RouterDestination {
    case editDeviceName(text: Binding<String>, onSave: () -> Void)
    case defaultPasswordsListAction(picker: SettingsPicker<PasswordListAction>)
    case manageTags

    var id: String {
        switch self {
        case .editDeviceName: "editDeviceName"
        case .defaultPasswordsListAction: "defaultPasswordsListAction"
        case .manageTags: "manageTags"
        }
    }
}

@Observable
final class CustomizationPresenter {
    
    var destination: CustomizationDestination?

    var deviceName: String

    var selectedDefaultActionDesctiption: String {
        PasswordListActionFormatStyle().format(selectedDefaultAction)
    }
    private var selectedDefaultAction: PasswordListAction

    private let interactor: CustomizationModuleInteracting

    init(interactor: CustomizationModuleInteracting) {
        self.interactor = interactor
        self.deviceName = interactor.deviceName
        self.selectedDefaultAction = interactor.defaultPassswordListAction
    }

    func onEditDeviceName() {
        var editingText = deviceName
        destination = .editDeviceName(
            text: Binding(
                get: { editingText },
                set: { newValue in
                    editingText = newValue
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.deviceName = trimmed.isEmpty ? self.interactor.deviceName : trimmed
                }
            ),
            onSave: { [self] in
                interactor.setDeviceName(deviceName)
            }
        )
    }

    func onChangeDefaultAction() {
        destination = .defaultPasswordsListAction(picker: .init(
            options: [.viewDetails, .copy, .edit],
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
    
    func onManageTags() {
        destination = .manageTags
    }
}
