// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension View {

    func backupConfigEditorUnsavedChangesAlert(
        isPresented: Binding<Bool>,
        onDiscard: @escaping () -> Void
    ) -> some View {
        alert(
            Text(.backupConfigsUnsavedChangesDialogTitle),
            isPresented: isPresented
        ) {
            Button(role: .destructive, action: onDiscard) {
                Text(.commonDiscardChanges)
            }
            Button(.commonCancel, role: .cancel) {}
        } message: {
            Text(.backupConfigsUnsavedChangesDialogDescription)
        }
    }
}
