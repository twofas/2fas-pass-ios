// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct BackupExportFileRouter: Router {
    
    @MainActor
    static func buildView(onClose: @escaping Callback) -> some View {
        BackupExportFileView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.backupExportFileModuleInteractor(),
            onClose: onClose
        ))
    }
    
    func routingType(for destination: BackupExportFileDestination?) -> RoutingType? {
        switch destination {
        case .shareFile: .sheet
        case .success, .failure: .push
        case nil: nil
        }
    }
    
    func view(for destination: BackupExportFileDestination) -> some View {
        switch destination {
        case .shareFile(let url, let onComplete, let onError):
            ShareSheetView(
                title: T.exportVaultTitle,
                url: url,
                activityComplete: onComplete,
                activityError: onError
            )
        case .success(let onClose):
            BackupExportFileSuccessView(onClose: onClose)
        case .failure(let onClose):
            BackupExportFileFailureView(onClose: onClose)
        }
    }
}
