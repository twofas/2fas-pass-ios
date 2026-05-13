// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

enum BackupConfigsAddDestination: RouterDestination {
    /// `onClose` receives the new config's id on a successful save (the View writes it
    /// into `savedConfigID` so the parent's matched-zoom destination flips to the new
    /// row before the sheet animates away), or `nil` on plain cancel/dismiss. The
    /// closure itself is responsible for dismissing the sheet — the form view doesn't
    /// know it's hosted in one.
    case webDAV(onClose: (BackupConfig.ID?) -> Void)
    case s3(onClose: (BackupConfig.ID?) -> Void)

    /// Explicit `String` id (not `Self`) because the associated `onClose` closures
    /// aren't `Hashable`. Cases without payloads are still distinct — switch ignores
    /// associated values.
    var id: String {
        switch self {
        case .webDAV: "webDAV"
        case .s3: "s3"
        }
    }
}

@Observable @MainActor
final class BackupConfigsAddPresenter {

    let canAddiCloud: Bool
    
    var destination: BackupConfigsAddDestination?

    private let interactor: BackupConfigsAddModuleInteracting

    init(interactor: BackupConfigsAddModuleInteracting) {
        self.interactor = interactor
        self.canAddiCloud = interactor.canAddiCloud
    }
    
    func selectWebDAV(onClose: @escaping (BackupConfig.ID?) -> Void) {
        destination = .webDAV(onClose: onClose)
    }

    func selectS3(onClose: @escaping (BackupConfig.ID?) -> Void) {
        destination = .s3(onClose: onClose)
    }

    /// Adds an iCloud config. Returns the new config's id on success (so the View can
    /// write it into `savedConfigID` for the matched-zoom destination flip and dismiss
    /// the sheet), or `nil` if iCloud was unavailable.
    func performIcloudAdd() -> BackupConfig.ID? {
        interactor.addiCloud()
    }
}
