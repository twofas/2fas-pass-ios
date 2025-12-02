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
    
    let createdAt: String
    let modifiedAt: String
    let tags: String?
    
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
    
    private let item: any ItemDataType
    private let configuration: ItemDetailFormConfiguration
    
    let dateFormatter: DateFormatter
        
    private static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }
    
    init(item: any ItemDataType, configuration: ItemDetailFormConfiguration) {
        self.item = item
        self.configuration = configuration

        let dateFormatter = Self.makeDateFormatter()
        self.dateFormatter = dateFormatter
        
        self.createdAt = dateFormatter.string(from: item.creationDate)
        self.modifiedAt = dateFormatter.string(from: item.modificationDate)
        
        if let tagIds = item.tagIds, tagIds.isEmpty == false {
            tags = configuration.interactor.fetchTags(for: tagIds).map(\.name).joined(separator: ", ")
        } else {
            tags = nil
        }
    }
}
