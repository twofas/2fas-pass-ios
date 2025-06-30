// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

enum VaultDecryptionKitDestination: Identifiable {
    
    var id: String {
        switch self {
        case .shareSheet: "shareSheet"
        case .setupComplete: "setupComplete"
        case .settings: "settings"
        }
    }
    
    case setupComplete
    case settings(includeMasterKey: Binding<Bool>)
    case shareSheet(url: URL, complete: Callback, error: Callback)
}

@Observable
final class VaultDecryptionKitPresenter {
    
    let kind: VaultDecryptionKitKind
    private let interactor: RecoveryKitModuleInteracting
    private let onFinish: Callback
    
    var isToggleOn = false
    
    private(set) var includeMasterKey: Bool = true
    
    var savePDFDisabled: Bool {
        isToggleOn == false
    }
    
    var destination: VaultDecryptionKitDestination? {
        didSet {
            if destination == nil {
                isPDFSaving = false
            }
        }
    }
    
    private(set) var isPDFSaving: Bool = false
        
    init(kind: VaultDecryptionKitKind, interactor: RecoveryKitModuleInteracting, onFinish: @escaping Callback) {
        self.kind = kind
        self.interactor = interactor
        self.onFinish = onFinish
    }
    
    func onSaveRecoveryKit() {
        isPDFSaving = true
        interactor.generateRecoveryKitPDF(includeMasterKey: includeMasterKey) { [weak self] url in
            guard let url else {
                self?.isPDFSaving = false
                return
            }
            
            self?.destination = .shareSheet(url: url, complete: { [weak self] in
                self?.destination = nil
                self?.onConfirmSaveFile()
            }, error: {
                self?.isPDFSaving = false
                self?.destination = nil
            })
        }
    }
    
    func onConfirmSaveFile() {
        switch kind {
        case .onboarding:
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(700))
                isPDFSaving = false
                destination = .setupComplete
            }
        default:
            isPDFSaving = false
        }
        
        onFinish()
        interactor.clear()
    }
    
    func onSettings() {
        destination = .settings(
            includeMasterKey: Binding(get: {
                self.includeMasterKey
            }, set: {
                self.includeMasterKey = $0
            })
        )
    }
}
