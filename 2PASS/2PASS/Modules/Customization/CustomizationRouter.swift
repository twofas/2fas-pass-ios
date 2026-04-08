// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct CustomizationRouter: Router {

    static func buildView() -> some View {
        CustomizationView(presenter: .init(interactor: ModuleInteractorFactory.shared.customizationModuleInteractor()))
    }
    
    func routingType(for destination: CustomizationDestination?) -> RoutingType? {
        switch destination {
        case .editDeviceName:
            return .push
        case .defaultPasswordsListAction:
            return .push
        case .manageTags:
            return .push
        case nil:
            return nil
        }
    }

    @ViewBuilder
    func view(for destination: CustomizationDestination) -> some View {
        switch destination {
        case .editDeviceName(let text, let onSave):
            SettingsTextFieldView(
                title: Text(.settingsEntryDeviceNickname),
                text: text,
                onSave: onSave
            )

        case .defaultPasswordsListAction(let picker):
            SettingsPickerView(
                title: Text(.settingsEntryLoginClickAction),
                footer: Text(.settingsEntryLoginClickActionDescription),
                picker: picker
            )

        case .manageTags:
            ManageTagsRouter.buildView()
        }
    }
}
