// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

protocol ItemDetailFormPresenting {
    func reload()
}

typealias ItemDetailFormPresenter = _ItemDetailFormPresenter & ItemDetailFormPresenting

struct ItemDetailFormConfiguration {
    let flowController: ItemDetailFlowControlling
    let interactor: ItemDetailModuleInteracting
    let toastPresenter: ToastPresenter
    let autoFillEnvironment: AutoFillEnvironment?
}

@Observable
class _ItemDetailFormPresenter {

    private(set) var createdAt: String
    private(set) var modifiedAt: String
    private(set) var tags: [ItemTagData]

    var name: String {
        item.name ?? ""
    }

    var protectionLevel: ItemProtectionLevel {
        item.protectionLevel
    }
    
    var flowController: ItemDetailFlowControlling {
        configuration.flowController
    }
    
    var autoFillEnvironment: AutoFillEnvironment? {
        configuration.autoFillEnvironment
    }
    
    var toastPresenter: ToastPresenter {
        configuration.toastPresenter
    }
    
    var interactor: ItemDetailModuleInteracting {
        configuration.interactor
    }
    
    var item: any ItemDataType {
        didSet {
            createdAt = dateFormatter.string(from: item.creationDate)
            modifiedAt = dateFormatter.string(from: item.modificationDate)
            tags = Self.tags(for: item, interactor: configuration.interactor)
        }
    }
    
    private let configuration: ItemDetailFormConfiguration
    
    let dateFormatter: DateFormatter
        
    private static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }
    
    private static func tags(for item: any ItemDataType, interactor: ItemDetailModuleInteracting) -> [ItemTagData] {
        guard let tagIds = item.tagIds, tagIds.isEmpty == false else { return [] }
        return interactor.fetchTags(for: tagIds)
    }
    
    init(item: any ItemDataType, configuration: ItemDetailFormConfiguration) {
        self.item = item
        self.configuration = configuration
        
        let dateFormatter = Self.makeDateFormatter()
        self.dateFormatter = dateFormatter
        
        self.createdAt = dateFormatter.string(from: item.creationDate)
        self.modifiedAt = dateFormatter.string(from: item.modificationDate)
        self.tags = Self.tags(for: item, interactor: configuration.interactor)
    }
}
