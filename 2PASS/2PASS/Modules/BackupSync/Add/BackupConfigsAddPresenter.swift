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
    /// Injected at construction so the View doesn't need `@Environment(\.dismiss)` or a
    /// `savedConfigID` binding. Called with the new config's id on success (so the parent
    /// can flip its matched-zoom destination to the new row before the sheet animates
    /// away) or `nil` on plain cancel.
    private let onClose: (BackupConfig.ID?) -> Void

    init(
        interactor: BackupConfigsAddModuleInteracting,
        onClose: @escaping (BackupConfig.ID?) -> Void
    ) {
        self.interactor = interactor
        self.canAddiCloud = interactor.canAddiCloud
        self.onClose = onClose
    }

    func selectWebDAV() {
        destination = .webDAV(onClose: onClose)
    }

    func selectS3() {
        destination = .s3(onClose: onClose)
    }

    func performIcloudAdd() {
        onClose(interactor.addiCloud())
    }

    func cancel() {
        onClose(nil)
    }
}
