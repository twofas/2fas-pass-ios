// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

@Observable
final class WiFiEditorFormPresenter: ItemEditorFormPresenter {

    var ssid: String = ""
    var password: String = ""
    var notes: String = ""
    var securityType: WiFiContent.SecurityType = .wpa2
    var hidden: Bool = false

    private var initialWiFiItem: WiFiItemData? {
        initialData as? WiFiItemData
    }

    private let initialPassword: String

    var ssidChanged: Bool {
        guard let initialWiFiItem else { return false }
        return ssid != (initialWiFiItem.content.ssid ?? "")
    }

    var passwordChanged: Bool {
        guard initialWiFiItem != nil else { return false }
        return password != initialPassword
    }

    var notesChanged: Bool {
        guard let initialWiFiItem else { return false }
        return notes != (initialWiFiItem.content.notes ?? "")
    }

    var securityTypeChanged: Bool {
        guard let initialWiFiItem else { return false }
        return securityType != initialWiFiItem.content.securityType
    }

    var hiddenChanged: Bool {
        guard let initialWiFiItem else { return false }
        return hidden != initialWiFiItem.content.hidden
    }

    init(
        interactor: ItemEditorModuleInteracting,
        flowController: ItemEditorFlowControlling,
        initialData: WiFiItemData? = nil,
        changeRequest: WiFiDataChangeRequest? = nil
    ) {
        if let initialData {
            let decryptedPassword = initialData.content.password.flatMap {
                interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
            } ?? ""

            self.ssid = changeRequest?.ssid ?? initialData.content.ssid ?? ""
            self.password = changeRequest?.password ?? decryptedPassword
            self.notes = changeRequest?.notes ?? initialData.content.notes ?? ""
            self.initialPassword = decryptedPassword
            self.securityType = changeRequest?.securityType ?? initialData.content.securityType
            self.hidden = changeRequest?.hidden ?? initialData.content.hidden
        } else {
            self.ssid = changeRequest?.ssid ?? ""
            self.password = changeRequest?.password ?? ""
            self.notes = changeRequest?.notes ?? ""
            self.initialPassword = ""
            self.securityType = changeRequest?.securityType ?? .wpa2
            self.hidden = changeRequest?.hidden ?? false
        }

        super.init(
            interactor: interactor,
            flowController: flowController,
            initialData: initialData,
            changeRequest: changeRequest
        )
    }

    func onSave() -> SaveItemResult {
        interactor.saveWiFi(
            name: name,
            ssid: ssid.nonBlankTrimmedOrNil,
            password: password.nonBlankTrimmedOrNil,
            notes: notes.nonBlankTrimmedOrNil,
            securityType: securityType,
            hidden: hidden,
            protectionLevel: protectionLevel,
            tagIds: Array(selectedTags.map { $0.tagID })
        )
    }

    func onScanQRCode() {
        flowController.toWiFiNetworkQRCodeScanner { [weak self] scannedData in
            self?.applyScannedQRCode(scannedData)
        }
    }
}

private extension WiFiEditorFormPresenter {
    func applyScannedQRCode(_ scannedData: WiFiQRCodeData) {
        ssid = scannedData.ssid
        password = scannedData.password ?? ""
        hidden = scannedData.hidden

        let shouldKeepCurrentSecurityType = scannedData.securityType == .wpa && securityType.isWPA
        if shouldKeepCurrentSecurityType == false {
            securityType = scannedData.securityType
        }
    }
}
