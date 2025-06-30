// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import SwiftUI

struct BackupImportImportingRouter {
    
    static func buildView(input: BackupImportInput, onClose: @escaping Callback) -> some View {
        BackupImportImportingView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.backupImportImportingModuleInteractor(input: input),
            onClose: onClose)
        )
    }
}
