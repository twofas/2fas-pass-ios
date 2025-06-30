// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Storage
import Common
import CryptoKit

public protocol WebBrowsersInteracting: AnyObject {
    
    @MainActor
    func contains(publicKey: String) -> Bool
    
    @MainActor
    func getWebBrowser(publicKey: String) -> WebBrowser?
    
    @MainActor
    func list() -> [WebBrowser]
    
    @MainActor
    func insert(_ browser: WebBrowser)
    
    @MainActor
    func update(_ browser: WebBrowser)
    
    @MainActor
    func delete(_ browser: WebBrowser)
}

final class WebBrowsersInteractor: WebBrowsersInteracting {
    
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    func contains(publicKey: String) -> Bool {
        guard let key = symetricKey else {
            return false
        }
        
        let encryptedBrowsers = mainRepository.listEncryptedWebBrowsers()
        return encryptedBrowsers.contains(where: {
            mainRepository.decrypt($0.publicKey, key: key) == publicKey.data(using: .utf8)
        })
    }
    
    func getWebBrowser(publicKey: String) -> WebBrowser? {
        guard let key = symetricKey else {
            return nil
        }
        
        let encryptedBrowsers = mainRepository.listEncryptedWebBrowsers()
        for encryptedBrowser in encryptedBrowsers {
            if let webBrowser = makeWebBrowser(from: encryptedBrowser, key: key), webBrowser.publicKey == publicKey {
                return webBrowser
            }
        }
        return nil
    }
    
    func list() -> [WebBrowser] {
        guard let key = symetricKey else {
            return []
        }
        
        let encryptedBrowsers = mainRepository.listEncryptedWebBrowsers()
        
        var browsers: [WebBrowser] = []
        for encryptedBrowser in encryptedBrowsers {
            if let browser = makeWebBrowser(from: encryptedBrowser, key: key) {
                browsers.append(browser)
            }
        }
        return browsers
    }

    func insert(_ browser: WebBrowser) {
        guard let key = symetricKey else {
            return
        }
        
        guard let encrypted = makeEncryptedWebBrowser(from: browser, key: key) else {
            return
        }
   
        mainRepository.createEncryptedWebBrowser(encrypted)
        save()
    }
    
    func update(_ browser: WebBrowser) {
        guard let key = symetricKey else {
            return
        }
        
        guard let encrypted = makeEncryptedWebBrowser(from: browser, key: key) else {
            return
        }
        
        mainRepository.updateEncryptedWebBrowser(encrypted)
        save()
    }
    
    func delete(_ browser: WebBrowser) {
        mainRepository.deleteEncryptedWebBrowser(id: browser.id)
        save()
    }
    
    private func save() {
        mainRepository.saveEncryptedStorage()
    }
    
    private var symetricKey: SymmetricKey? {
        guard let appKey = mainRepository.appKey else {
            Log("WebBrowsersInteractor - Can't get App Key!", module: .interactor, severity: .error)
            return nil
        }
        
        guard let key = mainRepository.createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("WebBrowsersInteractor - Can't get Symmetric Key from App Key", module: .interactor, severity: .error)
            return nil
        }
        
        return key
    }
    
    private func makeWebBrowser(from encryptedBrowser: WebBrowserEncryptedData, key: SymmetricKey) -> WebBrowser? {
        guard let publicKeyData = mainRepository.decrypt(encryptedBrowser.publicKey, key: key),
              let publicKey = String(data: publicKeyData, encoding: .utf8),
              let extNameData = mainRepository.decrypt(encryptedBrowser.extName, key: key),
              let extName = String(data: extNameData, encoding: .utf8),
              let nameData = mainRepository.decrypt(encryptedBrowser.name, key: key),
              let name = String(data: nameData, encoding: .utf8),
              let versionData = mainRepository.decrypt(encryptedBrowser.version, key: key),
              let version = String(data: versionData, encoding: .utf8) else {
            Log("WebBrowsersInteractor - Can't decrypt data!", module: .interactor, severity: .error)
            return nil
        }
        
        let nextSessionID: Data? = {
            if let nextSessionIDEnc = encryptedBrowser.nextSessionID {
                guard let decrypted = mainRepository.decrypt(nextSessionIDEnc, key: key) else {
                    Log("WebBrowsersInteractor - Can't decrypt data!", module: .interactor, severity: .error)
                    return nil
                }
                return decrypted
            }
            return nil
        }()
        
        return WebBrowser(
            id: encryptedBrowser.id,
            publicKey: publicKey,
            name: name,
            version: version,
            extName: extName,
            firstConnectionDate: encryptedBrowser.firstConnectionDate,
            lastConnectionDate: encryptedBrowser.lastConnectionDate,
            nextSessionID: nextSessionID
        )
    }
    
    private func makeEncryptedWebBrowser(from browser: WebBrowser, key: SymmetricKey) -> WebBrowserEncryptedData? {
        guard let publicKeyData = browser.publicKey.data(using: .utf8),
              let extensionNameData = browser.extName.data(using: .utf8),
              let nameData = browser.name.data(using: .utf8),
              let versionData = browser.version.data(using: .utf8) else {
            Log("WebBrowsersInteractor - Can't encrypt data!", module: .interactor, severity: .error)
            return nil
        }
        
        guard let publicKeyEnc = mainRepository.encrypt(publicKeyData, key: key),
              let extensionNameEnc = mainRepository.encrypt(extensionNameData, key: key),
              let nameEnc = mainRepository.encrypt(nameData, key: key),
              let versionEnc = mainRepository.encrypt(versionData, key: key) else {
            Log("WebBrowsersInteractor - Can't encrypt data!", module: .interactor, severity: .error)
            return nil
        }

        let nextSessionIDEnc: Data? = {
            guard let nextSessionID = browser.nextSessionID else {
                return nil
            }
            guard let encrypted = mainRepository.encrypt(nextSessionID, key: key) else {
                Log("WebBrowsersInteractor - Can't encrypt data!", module: .interactor, severity: .error)
                return nil
            }
            return encrypted
        }()
        
        return WebBrowserEncryptedData(
            id: browser.id,
            publicKey: publicKeyEnc,
            name: nameEnc,
            version: versionEnc,
            extName: extensionNameEnc,
            firstConnectionDate: browser.firstConnectionDate,
            lastConnectionDate: browser.lastConnectionDate,
            nextSessionID: nextSessionIDEnc
        )
    }
}
