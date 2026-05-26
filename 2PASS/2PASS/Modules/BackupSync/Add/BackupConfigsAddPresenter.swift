// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

enum BackupConfigsAddDestination: RouterDestination {
    case webDAV(onClose: @MainActor (BackupConfig.ID?) -> Void)
    case s3(onClose: @MainActor (BackupConfig.ID?) -> Void)

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

    private let onClose: @MainActor (BackupConfig.ID?) -> Void

    init(
        interactor: BackupConfigsAddModuleInteracting,
        onClose: @escaping @MainActor (BackupConfig.ID?) -> Void
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

    func selectIcloud() {
        let id = interactor.addiCloud()
        onClose(id)
    }

    func cancel() {
        onClose(nil)
    }
}
