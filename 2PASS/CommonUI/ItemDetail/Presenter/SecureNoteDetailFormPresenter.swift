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
    
    var hasNote: Bool {
        secureNoteItem.content.text != nil
    }
    
    private(set) var note: String?
    
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
        note = interactor.decryptNote(in: secureNoteItem)
        
        withAnimation {
            isReveal = true
        }
    }
    
    private func refreshValues() {
        isReveal = hasNote && (isReveal || protectionLevel == .normal)
        
        if isReveal {
            note = interactor.decryptNote(in: secureNoteItem)
        }
    }
}
