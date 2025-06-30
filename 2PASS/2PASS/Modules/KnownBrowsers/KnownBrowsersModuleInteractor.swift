// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

@MainActor
protocol KnownBrowsersModuleInteracting: AnyObject {
    func list() -> [WebBrowser]
    func delete(_ browser: WebBrowser)
    func identiconSVG(for webBrowser: WebBrowser, colorScheme: ColorScheme) -> String?
}

final class KnownBrowsersModuleInteractor: KnownBrowsersModuleInteracting {
    
    let webBrowserInteractor: WebBrowsersInteracting
    let identiconInteractor: ConnectIdenticonInteracting
    
    init(webBrowserInteractor: WebBrowsersInteracting, identiconInteractor: ConnectIdenticonInteracting) {
        self.webBrowserInteractor = webBrowserInteractor
        self.identiconInteractor = identiconInteractor
    }
    
    func list() -> [WebBrowser] {
        webBrowserInteractor.list()
    }
    
    func delete(_ browser: WebBrowser) {
        webBrowserInteractor.delete(browser)
    }
    
    func identiconSVG(for webBrowser: WebBrowser, colorScheme: ColorScheme) -> String? {
        identiconInteractor.identiconSVG(fromPublicKey: webBrowser.publicKey, colorScheme: colorScheme)
    }
}
