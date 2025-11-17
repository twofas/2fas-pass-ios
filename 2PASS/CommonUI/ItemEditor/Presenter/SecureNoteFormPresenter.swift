// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable
final class SecureNoteEditorFormPresenter: ItemEditorFormPresenter {
    
    var isReveal: Bool {
        didSet {
            let text = decryptNote()
            self.text = text
            self.initialText = text
        }
    }
    
    var text: String = ""
    private var initialText: String?
    
    var textChanged: Bool {
        guard let initialText else {
            return false
        }
        return text != initialText
    }

    private var initialSecureNoteItem: SecureNoteItemData? {
        initialData as? SecureNoteItemData
    }
    
    init(interactor: ItemEditorModuleInteracting, flowController: ItemEditorFlowControlling, initialData: SecureNoteItemData? = nil, changeRequest: SecureNoteDataChangeRequest? = nil) {
        if let initialData {
            if initialData.protectionLevel == .normal || changeRequest != nil {
                let text = interactor.decryptNote(in: initialData) ?? ""
                self.text = changeRequest?.text ?? text
                self.initialText = text
                self.isReveal = true
            } else {
                self.isReveal = false
            }
        } else {
            self.text = changeRequest?.text ?? ""
            self.isReveal = true
        }
        
        super.init(interactor: interactor, flowController: flowController, initialData: initialData, changeRequest: changeRequest)
    }
    
    override func onSave() -> SaveItemResult {
        let text = {
            if isReveal {
                return self.text
            } else {
                return decryptNote()
            }
        }()
        
        return interactor.saveSecureNote(
            name: name,
            text: text.nilIfEmpty,
            protectionLevel: protectionLevel,
            tagIds: Array(selectedTags.map { $0.tagID })
        )
    }
    
    private func decryptNote() -> String {
        guard let initialSecureNoteItem  else { return "" }
        return interactor.decryptNote(in: initialSecureNoteItem) ?? ""
    }
}
