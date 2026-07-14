// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

@Observable
final class ShareLinkImportPasswordPresenter {

    var password = "" {
        didSet {
            if errorDescription != nil { errorDescription = nil }
        }
    }

    private(set) var errorDescription: String?

    private let onSubmit: (String) throws -> Void
    private let onClose: () -> Void

    init(
        onSubmit: @escaping (String) throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onSubmit = onSubmit
        self.onClose = onClose
    }

    func onSubmitPassword() {
        guard !password.isEmpty else { return }
        errorDescription = nil

        do {
            try onSubmit(password)
        } catch ShareLinkInteractorError.decryptionFailed {
            errorDescription = String(localized: .shareLinkImportIncorrectPassword)
        } catch {
            errorDescription = error.localizedDescription
        }
    }

    func onCancel() {
        onClose()
    }
}
