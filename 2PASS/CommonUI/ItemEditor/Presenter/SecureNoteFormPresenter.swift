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
            guard isReveal else { return }
            
            let text = decryptNote()
            self.text = text
            self.initialText = text
        }
    }
    
    var text: String = ""
    var additionalInfo: String?
    private var initialText: String?
    
    var textChanged: Bool {
        guard let initialText else {
            return false
        }
        return text != initialText
    }
    
    var additionalInfoChanged: Bool {
        guard let initialSecureNoteItem else {
            return false
        }
        return (additionalInfo ?? "") != (initialSecureNoteItem.content.additionalInfo ?? "")
    }

    private var initialSecureNoteItem: SecureNoteItemData? {
        initialData as? SecureNoteItemData
    }
    
    init(interactor: ItemEditorModuleInteracting, flowController: ItemEditorFlowControlling, initialData: SecureNoteItemData? = nil, changeRequest: SecureNoteDataChangeRequest? = nil) {
        if let initialData {
            if initialData.protectionLevel == .normal || changeRequest != nil {
                let text = initialData.content.text.flatMap {
                    interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
                } ?? ""
                self.text = changeRequest?.text ?? text
                self.initialText = text
                self.isReveal = true
            } else {
                self.isReveal = false
            }
            
            self.additionalInfo = changeRequest?.additionalInfo ?? initialData.content.additionalInfo
        } else {
            self.text = changeRequest?.text ?? ""
            self.isReveal = true
        }

        super.init(interactor: interactor, flowController: flowController, initialData: initialData, changeRequest: changeRequest)
    }
    
    func onSave() -> SaveItemResult {
        let text = {
            if isReveal {
                return self.text
            } else {
                return decryptNote()
            }
        }()
        
        return interactor.saveSecureNote(
            name: name,
            text: text.nonBlankTrimmedOrNil,
            additionalInfo: additionalInfo?.nonBlankTrimmedOrNil,
            protectionLevel: protectionLevel,
            tagIds: Array(selectedTags.map { $0.tagID })
        )
    }
    
    private func decryptNote() -> String {
        guard let initialSecureNoteItem,
              let encrypted = initialSecureNoteItem.content.text else { return "" }
        return interactor.decryptSecureField(encrypted, protectionLevel: initialSecureNoteItem.protectionLevel) ?? ""
    }
}
