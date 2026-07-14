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
    case defaultURIMatchRule(picker: SettingsPicker<PasswordURI.Match>)
    case manageTags

    var id: String {
        switch self {
        case .editDeviceName: "editDeviceName"
        case .defaultPasswordsListAction: "defaultPasswordsListAction"
        case .defaultURIMatchRule: "defaultURIMatchRule"
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

    var selectedDefaultURIMatchRuleDescription: String {
        URIMatchRuleFormatStyle().format(selectedDefaultURIMatchRule)
    }
    private var selectedDefaultURIMatchRule: PasswordURI.Match

    private let interactor: CustomizationModuleInteracting

    init(interactor: CustomizationModuleInteracting) {
        self.interactor = interactor
        self.deviceName = interactor.deviceName
        self.selectedDefaultAction = interactor.defaultPassswordListAction
        self.selectedDefaultURIMatchRule = interactor.defaultURIMatchRule
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
    
    func onChangeDefaultURIMatchRule() {
        destination = .defaultURIMatchRule(picker: .init(
            options: PasswordURI.Match.allCases,
            selected: Binding(get: {
                self.selectedDefaultURIMatchRule
            }, set: { rule in
                if let rule {
                    self.selectedDefaultURIMatchRule = rule
                    self.interactor.setDefaultURIMatchRule(rule)
                }
            }),
            formatter: {
                URIMatchRuleFormatStyle().format($0)
            })
        )
    }

    func onManageTags() {
        destination = .manageTags
    }
}
