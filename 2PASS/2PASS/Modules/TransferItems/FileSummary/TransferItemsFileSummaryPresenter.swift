// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import Data

enum TransferItemsFileSummaryDestination: RouterDestination {
    case importItems(ExternalServiceImportResult, service: ExternalService, onClose: Callback)

    var id: String {
        switch self {
        case .importItems: "importItems"
        }
    }
}

@Observable
final class TransferItemsFileSummaryPresenter {

    let service: ExternalService
    let result: ExternalServiceImportResult

    let contentTypes: [ItemContentType]
    let summary: [ItemContentType: Int]

    var destination: TransferItemsFileSummaryDestination?

    private let onClose: Callback

    init(service: ExternalService, result: ExternalServiceImportResult, onClose: @escaping Callback) {
        self.service = service
        self.result = result
        self.onClose = onClose

        let summary: [ItemContentType: Int] = result.items.reduce(into: [:], { result, item in
            let count = result[item.contentType] ?? 0
            result[item.contentType] = count + 1
        })

        self.contentTypes = ItemContentType.allKnownTypes.filter { summary[$0] != nil }
        self.summary = summary
    }

    func onProceed() {
        destination = .importItems(result, service: service, onClose: onClose)
    }
}
