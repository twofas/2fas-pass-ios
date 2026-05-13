// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

enum BackupConfigsAddDestination: RouterDestination {
    /// `onClose` receives the new config's UUID on a successful save (the View writes it
    /// into `savedConfigID` so the parent's matched-zoom destination flips to the new
    /// row before the sheet animates away), or `nil` on plain cancel/dismiss. The
    /// closure itself is responsible for dismissing the sheet — the form view doesn't
    /// know it's hosted in one.
    case webDAV(onClose: (UUID?) -> Void)
    case s3(onClose: (UUID?) -> Void)

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
    
    func selectWebDAV(onClose: @escaping (UUID?) -> Void) {
        destination = .webDAV(onClose: onClose)
    }

    func selectS3(onClose: @escaping (UUID?) -> Void) {
        destination = .s3(onClose: onClose)
    }

    /// Adds an iCloud config. Returns the new config's UUID on success (so the View can
    /// write it into `savedConfigID` for the matched-zoom destination flip and dismiss
    /// the sheet), or `nil` if iCloud was unavailable.
    func performIcloudAdd() -> UUID? {
        interactor.addiCloud()
    }
}
