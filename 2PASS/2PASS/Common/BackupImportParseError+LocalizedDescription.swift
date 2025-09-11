// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

extension BackupImportParseError {
    var localizedDescription: String {
        switch self {
        case .corruptedFile(let error): "File is corrupted:\n\(error.localizedDescription)"
        case .nothingToImport: "File doesn't contain any passwords."
        case .errorDecrypting: "There was an error while decrypting the file. Try again."
        case .otherDeviceId: "This file was synchronized on a different device."
        case .passwordChanged: ""
        case .schemaNotSupported(let schemeVersion, _): T.importInvalidSchemaErrorMsg(schemeVersion)
        }
    }
}
