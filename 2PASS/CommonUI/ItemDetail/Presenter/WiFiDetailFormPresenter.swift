// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable
final class WiFiDetailFormPresenter: ItemDetailFormPresenter {

    private(set) var wifiItem: WiFiItemData

    private let passwordPlaceholder = "••••••••••••"
    private var decryptedPassword: String?

    var ssid: String? {
        wifiItem.content.ssid
    }

    var securityType: WiFiContent.SecurityType {
        wifiItem.content.securityType
    }

    var isHiddenNetwork: Bool {
        wifiItem.content.hidden
    }

    var notes: String? {
        wifiItem.content.notes
    }

    var isPasswordAvailable = false
    var password: String?
    
    var canShowNetworkQRCode: Bool {
        ssid?.isEmpty == false && (wifiItem.content.password == nil || decryptedPassword != nil)
    }

    init(item: WiFiItemData, configuration: ItemDetailFormConfiguration) {
        self.wifiItem = item
        super.init(item: item, configuration: configuration)
        refreshValues()
    }

    func reload() {
        guard let newWiFiItem = interactor.fetchItem(for: wifiItem.id)?.asWiFi else {
            return
        }
        wifiItem = newWiFiItem
        refreshValues()
    }

    func onSelectPassword() {
        guard isPasswordAvailable, let decryptedPassword else { return }

        if autoFillEnvironment?.isTextToInsert == true {
            if #available(iOS 18.0, *) {
                flowController.autoFillTextToInsert(decryptedPassword)
            }
        } else {
            password = decryptedPassword
        }
    }

    func onCopyPassword() {
        guard let decryptedPassword else { return }
        interactor.copy(decryptedPassword)
        toastPresenter.presentPasswordCopied()
    }

    func onSelectSSID() {
        guard #available(iOS 18.0, *),
              autoFillEnvironment?.isTextToInsert == true,
              let ssid else {
            return
        }
        flowController.autoFillTextToInsert(ssid)
    }

    func onCopySSID() {
        guard let ssid else {
            return
        }
        interactor.copy(ssid)
        toastPresenter.presentCopied()
    }

    func onShowNetworkQRCode() {
        guard canShowNetworkQRCode, let ssid else {
            toastPresenter.present(
                .commonGeneralErrorTryAgain,
                style: .failure
            )
            return
        }
        flowController.toWiFiNetworkQRCode(
            ssid: ssid,
            payload: interactor.makeWiFiQRCodePayload(
                from: .init(
                    ssid: ssid,
                    password: decryptedPassword,
                    securityType: wifiItem.content.securityType,
                    hidden: wifiItem.content.hidden
                )
            )
        )
    }
}

private extension WiFiDetailFormPresenter {
    func refreshValues() {
        guard let encryptedPassword = wifiItem.content.password else {
            isPasswordAvailable = false
            decryptedPassword = nil
            password = nil
            return
        }

        guard let decrypted = interactor.decryptSecureField(encryptedPassword, protectionLevel: wifiItem.protectionLevel) else {
            isPasswordAvailable = false
            decryptedPassword = nil
            password = nil
            return
        }

        isPasswordAvailable = true
        decryptedPassword = decrypted
        password = passwordPlaceholder
    }
}
