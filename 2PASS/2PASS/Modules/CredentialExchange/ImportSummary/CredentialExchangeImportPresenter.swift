// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import Data
import AuthenticationServices

@available(iOS 26.0, *)
enum CredentialExchangeImportViewState {
    case loading
    case summary
    case error
}

@available(iOS 26.0, *)
enum CredentialExchangeImportDestination: RouterDestination {
    case performImport(result: ExternalServiceImportResult, onClose: Callback)

    var id: String {
        switch self {
        case .performImport: "performImport"
        }
    }
}

@available(iOS 26.0, *)
@Observable @MainActor
final class CredentialExchangeImportPresenter {

    var destination: CredentialExchangeImportDestination?

    private(set) var viewState: CredentialExchangeImportViewState = .loading
    
    private(set) var exporterDisplayName: String = ""
    private(set) var exporterRelyingPartyIdentifier: String = ""
    private(set) var importResult: ExternalServiceImportResult?
    private(set) var contentTypes: [ItemContentType] = []
    private(set) var summary: [ItemContentType: Int] = [:]
    private(set) var tagsCount: Int = 0
    private(set) var itemsConvertedToSecureNotes: Int = 0

    private let credentials: ASExportedCredentialData
    
    private let interactor: CredentialExchangeImportModuleInteracting
    let onClose: Callback

    init(data: ASExportedCredentialData, interactor: CredentialExchangeImportModuleInteracting, onClose: @escaping Callback) {
        self.credentials = data
        self.interactor = interactor
        self.onClose = onClose
    }

    func onAppear() async {
        guard viewState == .loading else { return }

        exporterDisplayName = credentials.exporterDisplayName
        exporterRelyingPartyIdentifier = credentials.exporterRelyingPartyIdentifier

        do {
            let result = try interactor.convertCredentials(credentials)
            importResult = result
            itemsConvertedToSecureNotes = result.itemsConvertedToSecureNotes

            var counts: [ItemContentType: Int] = result.items.reduce(into: [:]) { result, item in
                result[item.contentType, default: 0] += 1
            }

            tagsCount = result.tags.count

            // Subtract converted items from secure notes count
            if let secureNoteCount = counts[.secureNote], result.itemsConvertedToSecureNotes > 0 {
                let adjustedCount = secureNoteCount - result.itemsConvertedToSecureNotes
                if adjustedCount > 0 {
                    counts[.secureNote] = adjustedCount
                } else {
                    counts.removeValue(forKey: .secureNote)
                }
            }

            contentTypes = ItemContentType.allKnownTypes.filter { counts[$0] != nil }
            summary = counts
            viewState = .summary
        } catch {
            Log("Credential exchange conversion failed: \(error)", module: .moduleInteractor)
            viewState = .error
        }
    }

    func startImport() {
        guard destination == nil else { return }
        guard let importResult else { return }

        destination = .performImport(
            result: importResult,
            onClose: onClose
        )
    }
}
