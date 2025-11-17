// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable
class ItemEditorFormPresenter {
    
    var name: String
    var protectionLevel: ItemProtectionLevel
    var selectedTags: [ItemTagData] = []
    
    let initialData: (any ItemDataType)?
    let interactor: ItemEditorModuleInteracting
    let flowController: ItemEditorFlowControlling
    
    var canSave: Bool {
        name.isEmpty == false
    }
    
    var nameChanged: Bool {
        guard let initialData else {
            return false
        }
        return name != (initialData.name ?? "")
    }
    
    var protectionLevelChanged: Bool {
        guard let initialData else {
            return false
        }
        return protectionLevel != initialData.protectionLevel
    }
    
    var tagsChanged: Bool {
        guard let initialData else {
            return false
        }
        return selectedTags.map { $0.id } != (initialData.tagIds ?? [])
    }
    
    init(interactor: ItemEditorModuleInteracting, flowController: ItemEditorFlowControlling, initialData: (any ItemDataType)? = nil, changeRequest: (any ItemDataChangeRequest)? = nil) {
        self.initialData = initialData
        self.interactor = interactor
        self.flowController = flowController
        
        self.name = changeRequest?.name ?? initialData?.name ?? ""
        self.protectionLevel = changeRequest?.protectionLevel ?? initialData?.protectionLevel ?? interactor.currentDefaultProtectionLevel
        
        let tagIds = changeRequest?.tags ?? initialData?.tagIds
        if let tagIds, !tagIds.isEmpty {
            let tags = interactor.getTags(for: tagIds)
            selectedTags = tags
        } else {
            selectedTags = []
        }
    }
    
    func onSave() -> SaveItemResult {
        fatalError("Should be overridden")
    }
    
    func onChangeProtectionLevel() {
        flowController.toChangeProtectionLevel(current: protectionLevel)
    }
    
    func onSelectTags() {
        flowController.toSelectTags(selectedTags: selectedTags, onChange: { [weak self] tags in
            self?.selectedTags = tags
        })
    }
}
