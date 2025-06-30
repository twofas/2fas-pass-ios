// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Combine

@Observable
final class CustomizeIconPresenter {
    var enableSave: ((Bool) -> Void)?
    
    private let flowController: CustomizeIconFlowControlling
    private let interactor: CustomizeIconModuleInteracting
    
    var iconType: CustomizeIconType
    
    var labelTitle: String {
        didSet {
            refreshLabelIcon()
        }
    }
    var labelColor: UIColor? {
        didSet {
            refreshLabelIcon()
        }
    }
    
    var selectedDomain: String? {
        didSet {
            if selectedDomain != oldValue {
                refreshDomainIcon()
            }
        }
    }
    let uriDomains: [String]
    
    var icon: UIImage?
    var urlString: String = "" {
        didSet {
            if urlString != oldValue {
                refreshCustomIcon()
            }
        }
    }
    
    private(set) var labelIconContent: IconContent?
    private(set) var domainIconContent: IconContent?
    private(set) var customIconContent: IconContent = .placeholder
    
    private let defaultLabel: String
    private var fetchTask: Task<Void, Never>?
    
    init(
        data: CustomizeIconData,
        flowController: CustomizeIconFlowControlling,
        interactor: CustomizeIconModuleInteracting
    ) {
        self.flowController = flowController
        self.interactor = interactor
        
        iconType = data.current.toCustomizeIconType()
        
        defaultLabel = Config.defaultIconLabel(forName: data.name)
        labelTitle = data.labelTitle
        labelColor = data.labelColor
        uriDomains = data.uriDomains.filter { $0.isEmpty == false }
        selectedDomain = data.iconDomain ?? data.uriDomains.first
        
        if iconType == .custom {
            urlString = data.iconCustomURL?.absoluteString ?? ""
        }

        refreshDomainIcon()
        refreshLabelIcon()
        refreshCustomIcon()
    }
}

extension CustomizeIconPresenter {
    func onAppear() {
        enableSave?(false)
    }
    
    func onResetColor() {
        labelColor = nil
    }
    
    func onIconTypeChange(_ newIconType: CustomizeIconType) {
        self.iconType = newIconType
        refreshDomainIcon()
    }
    
    func onLabelTitleChange(oldValue: String, newValue: String) {
        let newValue = newValue.trim().uppercased()
        if newValue.count > Config.maxLabelLength{
            labelTitle = newValue.twoLetters
            return
        }
        labelTitle = newValue
    }
    
    func onLabelColorChange(_ newColor: UIColor) {
        labelColor = newColor
    }
    
    func onSave() {
        let selectedDomain: String? = {
            switch iconType {
            case .icon:
                return self.selectedDomain
            case .custom, .label:
                return nil
            }
        }()
        
        let url: URL? = {
            switch iconType {
            case .icon:
                return nil
            case .custom:
                return URL(string: urlString)
            case .label:
                return nil
            }
        }()
        
        guard isInputValid(), let passwordType = iconType.toPasswordIconType(labelTitle: labelTitle, labelColor: labelColor, iconDomain: selectedDomain, iconCustomURL: url) else { return }
        flowController.toSave(value: passwordType)
    }
}

private extension CustomizeIconPresenter {
    
    func refreshDomainIcon() {
        enableSave?(isInputValid())
        
        if let selectedDomain, let url = Config.iconURL(forDomain: selectedDomain) {
            domainIconContent = .loading

            fetchTask?.cancel()
            fetchTask = Task { @MainActor in
                if let data = try? await interactor.fetchIconImage(from: url), let image = UIImage(data: data) {
                    domainIconContent = .icon(image)
                } else {
                    domainIconContent = .label(labelTitle, color: nil)
                }
            }
        } else {
            domainIconContent = .label(defaultLabel, color: nil)
        }
    }
    
    func refreshCustomIcon() {
        enableSave?(isInputValid())

        if let url = URL(string: urlString) {
            customIconContent = .loading

            fetchTask?.cancel()
            fetchTask = Task { @MainActor in
                if let data = try? await interactor.fetchIconImage(from: url), let image = UIImage(data: data) {
                    customIconContent = .icon(image)
                } else {
                    customIconContent = .placeholder
                }
            }
        } else {
            customIconContent = .placeholder
        }
    }
    
    func refreshLabelIcon() {
        enableSave?(isInputValid())

        labelIconContent = .label(labelTitle, color: labelColor)
    }
    
    func isInputValid() -> Bool {
        switch iconType {
        case .label:
            return !labelTitle.isEmpty
        case .custom:
            return urlString.isEmpty == false
        case .icon:
            return true
        }
    }
}
