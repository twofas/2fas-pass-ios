// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Data
import SwiftData
import CommonUI
import Common

enum KnownBrowsersDestination: RouterDestination {
    case confirmDeletion(onConfirm: Callback)
    
    var id: String {
        switch self {
        case .confirmDeletion:
            "confirmDeletion"
        }
    }
}

@Observable @MainActor
final class KnownBrowsersPresenter {
    
    var destination: KnownBrowsersDestination?
    
    private(set) var browsers: [WebBrowser]
    private var identicons: [UUID: String] = [:]
    
    var isEmptyList: Bool {
        browsers.isEmpty
    }
    
    private let interactor: KnownBrowsersModuleInteracting
    
    init(interactor: KnownBrowsersModuleInteracting) {
        self.interactor = interactor
        self.browsers = interactor.list()
    }
    
    func onDelete(_ browser: WebBrowser) {
        destination = .confirmDeletion(onConfirm: { [weak self] in
            self?.deleteBrowser(browser)
        })
    }
    
    func onAppear(colorScheme: SwiftUI.ColorScheme) {
        browsers = interactor.list()
        
        identicons = browsers.reduce(into: [:], { result, browser in
            result[browser.id] = {
                switch colorScheme {
                case .dark:
                    return interactor.identiconSVG(for: browser, colorScheme: .dark)
                default:
                    return interactor.identiconSVG(for: browser, colorScheme: .light)
                }
            }()
        })
    }
    
    func identicon(for browser: WebBrowser) -> String? {
        identicons[browser.id]
    }
    
    private func deleteBrowser(_ browser: WebBrowser) {
        browsers = browsers.filter { $0.id != browser.id }
        interactor.delete(browser)
    }
}

