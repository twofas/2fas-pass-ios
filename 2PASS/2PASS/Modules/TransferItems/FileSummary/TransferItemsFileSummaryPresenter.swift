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
    let tagsCount: Int
    let itemsConvertedToSecureNotes: Int

    var destination: TransferItemsFileSummaryDestination?

    private let onClose: Callback

    init(service: ExternalService, result: ExternalServiceImportResult, onClose: @escaping Callback) {
        self.service = service
        self.result = result
        self.onClose = onClose
        self.itemsConvertedToSecureNotes = result.itemsConvertedToSecureNotes

        var summary: [ItemContentType: Int] = result.items.reduce(into: [:], { result, item in
            let count = result[item.contentType] ?? 0
            result[item.contentType] = count + 1
        })

        self.tagsCount = result.tags.count
        
        // Subtract converted items from secure notes count
        if let secureNoteCount = summary[.secureNote], result.itemsConvertedToSecureNotes > 0 {
            let adjustedCount = secureNoteCount - result.itemsConvertedToSecureNotes
            if adjustedCount > 0 {
                summary[.secureNote] = adjustedCount
            } else {
                summary.removeValue(forKey: .secureNote)
            }
        }

        self.contentTypes = ItemContentType.allKnownTypes.filter { summary[$0] != nil }
        self.summary = summary
    }

    func onProceed() {
        destination = .importItems(result, service: service, onClose: onClose)
    }
}
