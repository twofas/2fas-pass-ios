// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import Data

struct BackupFlowContext {
    
    typealias ResultCallback = Callback
    
    enum Kind {
        case quickSetup
        case settings
    }
    
    let kind: Kind
    var onClose: ResultCallback?
    
    static var settings: Self {
        .init(kind: .settings)
    }
    
    static func quickSetup(onClose: @escaping ResultCallback) -> Self {
        .init(kind: .quickSetup, onClose: onClose)
    }
    
    private init(kind: Kind, onClose: ResultCallback? = nil) {
        self.kind = kind
        self.onClose = onClose
    }
}

enum BackupDestination: RouterDestination {
    case currentPassword(config: LoginModuleInteractorConfig, onSuccess: Callback)
    case export(onClose: Callback)
    case importFile(onClose: (FileImportResult) -> Void)
    case recoveryEnterPassword(ExchangeVaultVersioned, entropy: Entropy, onClose: Callback, onTryAgain: Callback)
    case recovery(ExchangeVaultVersioned, onClose: Callback)
    case importing(BackupImportInput, onClose: Callback)
    case importingFailure(onClose: Callback)
    case schemaNotSupported(schemaVersion: Int, onClose: Callback)
    case upgradePlanPrompt(itemsLimit: Int)
    
    var id: String {
        switch self {
        case .importFile: "import"
        case .currentPassword: "currentPassword"
        case .export: "export"
        case .recoveryEnterPassword: "recoveryEnterPassword"
        case .recovery: "recovery"
        case .importing: "importing"
        case .importingFailure: "importingFailure"
        case .schemaNotSupported: "schemaNotSupported"
        case .upgradePlanPrompt: "upgradePlanPrompt"
        }
    }
}

@Observable
final class BackupPresenter {
        
    var destination: BackupDestination?
    
    private(set) var isExportDisabled: Bool
    
    let flowContext: BackupFlowContext
    private let interactor: BackupModuleInteracting

    init(interactor: BackupModuleInteracting, flowContext: BackupFlowContext) {
        self.flowContext = flowContext
        self.interactor = interactor
        
        isExportDisabled = !interactor.hasItems
    }
}

extension BackupPresenter {
    
    func onAppear() {
        isExportDisabled = !interactor.hasItems
    }
    
    func onImport() {
        guard interactor.canImport else {
            destination = .upgradePlanPrompt(itemsLimit: interactor.currentPlanItemsLimit)
            return
        }
        
        destination = .importFile(onClose: { [weak self] result in
            self?.destination = nil

            switch result {
            case .fileOpen(let url):
                self?.openFile(at: url)
            case .cantReadFile:
                self?.destination = .importingFailure(onClose: { [weak self] in
                    self?.destination = nil
                })
            case .cancelled:
                break
            }
        })
    }
    
    private func openFile(at url: URL) {
        interactor.openFile(url: url) { [weak self] result in
            switch result {
            case .success(let data):
                self?.interactor.parseContents(of: data, completion: { [weak self] parseResult in
                    guard let self else { return }
                    switch parseResult {
                    case .success(let result):
                        switch result {
                        case .decrypted(let items, let tags, let deleted):
                            if interactor.isVaultInitialized() {
                                destination = .importing(
                                    .decrypted(items, tags: tags, deleted: deleted),
                                    onClose: { [weak self] in
                                        self?.close()
                                    }
                                )
                            } else {
                                destination = .importingFailure(onClose: { [weak self] in
                                    self?.close()
                                })
                            }
                        case .encrypted(let vault, let entropy):
                            if let entropy {
                                destination = .recoveryEnterPassword(
                                    vault,
                                    entropy: entropy,
                                    onClose: { [weak self] in
                                        self?.close()
                                    },
                                    onTryAgain: { [weak self] in
                                        self?.destination = nil
                                    }
                                )
                            } else {
                                destination = .recovery(vault, onClose: { [weak self] in
                                    self?.close()
                                })
                            }
                        }
                    case .failure(let error):
                        switch error {
                        case .schemaNotSupported(let schemaVersion):
                            destination = .schemaNotSupported(
                                schemaVersion: schemaVersion,
                                onClose: { [weak self] in
                                    self?.close()
                                }
                            )
                        default:
                            destination = .importingFailure(onClose: { [weak self] in
                                self?.close()
                            })
                        }
                    }
                })
            case .failure:
                self?.destination = .importingFailure(onClose: { [weak self] in
                    self?.close()
                })
            }
        }
    }
    
    func onExport() {
        Task { @MainActor in
            if await interactor.loginUsingBiometryIfAvailable() {
                destination = .export(onClose: { [weak self] in
                    self?.close()
                })
                
            } else {
                destination = .currentPassword(config: .init(allowBiometrics: true, loginType: .verify(savePassword: false)), onSuccess: { [weak self] in
                    self?.destination = nil
                    
                    Task { @MainActor in
                        try await Task.sleep(for: .milliseconds(700))
                        
                        self?.destination = .export(onClose: { [weak self] in
                            self?.close()
                        })
                    }
                })
            }
        }
    }
    
    private func close() {
        switch flowContext.kind {
        case .quickSetup:
            flowContext.onClose?()
        case .settings:
            destination = nil
        }
    }
}
