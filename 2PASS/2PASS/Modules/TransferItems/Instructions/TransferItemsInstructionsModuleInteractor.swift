// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol TransferItemsInstructionsModuleInteracting {
    var service: ExternalService { get }
    func transfer(from url: URL) async throws(ExternalServiceImportError) -> [ItemData]
}

final class TransferItemsInstructionsModuleInteractor: TransferItemsInstructionsModuleInteracting {
    
    let service: ExternalService
    let externalServiceImportInteractor: ExternalServiceImportInteracting
    
    init(service: ExternalService, externalServiceImportInteractor: ExternalServiceImportInteracting) {
        self.service = service
        self.externalServiceImportInteractor = externalServiceImportInteractor
    }
    
    func transfer(from url: URL) async throws(ExternalServiceImportError) -> [ItemData] {
        let data = try await externalServiceImportInteractor.openFile(from: url)
        return try await externalServiceImportInteractor.importService(service, content: data)
    }
}
