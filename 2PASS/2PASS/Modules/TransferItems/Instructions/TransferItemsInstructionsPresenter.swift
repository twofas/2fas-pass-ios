// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import Data

enum TransferItemsInstructionsDestination: RouterDestination {
    case uploadFile(ExternalService, onClose: (FileImportResult) -> Void)
    case summary(ExternalService, result: ExternalServiceImportResult, onClose: Callback)
    case importFailure(onClose: Callback)

    var id: String {
        switch self {
        case .uploadFile: "uploadFile"
        case .summary: "summary"
        case .importFailure: "importFailure"
        }
    }
}

@Observable
final class TransferItemsInstructionsPresenter {
    
    var service: ExternalService {
        interactor.service
    }
    
    var destination: TransferItemsInstructionsDestination?
    
    private(set) var isUploadingFile: Bool = false
    
    private let interactor: TransferItemsInstructionsModuleInteracting
    private let onClose: Callback
    
    init(interactor: TransferItemsInstructionsModuleInteracting, onClose: @escaping Callback) {
        self.interactor = interactor
        self.onClose = onClose
    }
    
    func onUploadFile() {
        destination = .uploadFile(service, onClose: { [weak self] result in
            self?.destination = nil
            
            switch result {
            case .fileOpen(let url):
                self?.transfer(from: url)
            case .cantReadFile:
                self?.toImportFailure()
            case .cancelled:
                break
            }
        })
    }
    
    private func transfer(from url: URL) {
        Task { @MainActor in
            do {
                isUploadingFile = true
                let result = try await interactor.transfer(from: url)
                isUploadingFile = false

                destination = .summary(service, result: result, onClose: onClose)
            } catch {
                isUploadingFile = false
                destination = .importFailure(onClose: onClose)
            }
        }
    }
    
    private func toImportFailure() {
        destination = .importFailure(onClose: onClose)
    }
}
