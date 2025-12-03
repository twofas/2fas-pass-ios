// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

@Observable
final class SecureNoteFormPresenter: ItemDetailFormPresenter {
    
    private(set) var secureNoteItem: SecureNoteItemData
    
    var isReveal = false
    var isNoteExpanded = false
    
    private(set) var note: String?
    
    var additionalInfo: String? {
        secureNoteItem.content.additionalInfo?.nilIfEmpty
    }
    
    init(item: SecureNoteItemData, configuration: ItemDetailFormConfiguration) {
        self.secureNoteItem = item
        super.init(item: item, configuration: configuration)
        refreshValues()
    }
    
    func reload() {
        guard let newSecureNote = interactor.fetchItem(for: secureNoteItem.id)?.asSecureNote else {
            return
        }
        self.secureNoteItem = newSecureNote
        refreshValues()
    }
    
    func onViewNote() {
        note = decryptNote()
        isReveal = true
    }

    func onSelectNote() {
        guard let note else { return }
        flowController.autoFillTextToInsert(note)
    }
    
    func onCopyNote() {
        guard let note else { return }
        interactor.copy(note)
        toastPresenter.presentCopied()
    }
    
    func onCopy(_ url: URL) {
        interactor.copy(url.absoluteString)
        toastPresenter.presentCopied()
    }
    
    func onOpen(_ url: URL) {
        UIApplication.shared.open(url)
    }
    
    private func refreshValues() {
        isReveal = (isReveal || protectionLevel == .normal)

        if isReveal {
            note = decryptNote()
        }
    }

    private func decryptNote() -> String? {
        guard let encrypted = secureNoteItem.content.text else { return nil }
        return interactor.decryptSecureField(encrypted, protectionLevel: secureNoteItem.protectionLevel)
    }
}
