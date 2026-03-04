// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data
import AuthenticationServices

@available(iOS 26.0, *)
protocol CredentialExchangeImportModuleInteracting: AnyObject {
    func convertCredentials(_ data: ASExportedCredentialData) throws(CredentialExchangeImportError) -> ExternalServiceImportResult
}

@available(iOS 26.0, *)
final class CredentialExchangeImportModuleInteractor: CredentialExchangeImportModuleInteracting {

    private let credentialExchangeImporter: CredentialExchangeImporting

    init(credentialExchangeImporter: CredentialExchangeImporting) {
        self.credentialExchangeImporter = credentialExchangeImporter
    }

    func convertCredentials(_ data: ASExportedCredentialData) throws(CredentialExchangeImportError) -> ExternalServiceImportResult {
        try credentialExchangeImporter.convert(data)
    }
}
