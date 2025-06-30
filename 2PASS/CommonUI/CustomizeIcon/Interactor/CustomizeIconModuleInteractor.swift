// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol CustomizeIconModuleInteracting: AnyObject {
    func fetchIconImage(from url: URL) async throws -> Data
}

final class CustomizeIconModuleInteractor {
    private let fileIconInteractor: FileIconInteracting
    
    init(fileIconInteractor: FileIconInteracting) {
        self.fileIconInteractor = fileIconInteractor
    }
}

extension CustomizeIconModuleInteractor: CustomizeIconModuleInteracting {
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
}
