// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CryptoKit
import Common
import Security
import SignalArgon2
import LocalAuthentication

extension MainRepositoryImpl {
    var deviceID: DeviceID? {
        guard _empheralDeviceID == nil else {
            return _empheralDeviceID
        }
        _empheralDeviceID = userDefaultsDataSource.deviceID
        return _empheralDeviceID
    }
    
    func generateUUID() -> UUID {
        UUID()
    }
    
    func saveDeviceID(_ deviceID: DeviceID) {
        userDefaultsDataSource.setDeviceID(deviceID)
        _empheralDeviceID = deviceID
    }
    
    func clearDeviceID() {
        userDefaultsDataSource.clearDeviceID()
        _empheralDeviceID = nil
    }
    
    func generateEntropy() -> Data? {
        let byteCount = 160 / 8
        var randomBytes = [UInt8](repeating: 0, count: byteCount)
        
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &randomBytes)
        
        guard status == errSecSuccess else {
            Log("Error while generating random data for Entropy!", module: .mainRepository, severity: .error)
            return nil
        }
        
        return Data(randomBytes)
    }
    
    func createSeed(from entropy: Data) -> Data {
        Data(SHA256.hash(data: entropy))
    }
    
    func convertWordsToDecimal(_ words: [String]) -> [Int]? {
        let words = words.map({ $0.lowercased() })
        guard let contentsOfFile = importBIP0039Words() else { return nil }
        var result: [Int] = []
        for word in words {
            guard let index = contentsOfFile.firstIndex(where: { $0 == word }) else {
                return nil
            }
            result.append(index)
        }
        return result
    }
    
    func create11BitPacks(from decimals: [Int]) -> [UInt16] {
        decimals.map({ UInt16($0) })
    }
    
    func create4BitPacksFrom11BitPacks(_ data: [UInt16]) -> [UInt8] {
        let bytesCount = 80
        let packsCount = 42 // + 1
        
        let mem = UnsafeMutableRawPointer.allocate(byteCount: bytesCount, alignment: MemoryLayout<UInt16>.alignment)
        for (index, l) in data.enumerated() {
            mem.storeBytes(of: l, toByteOffset: 2 * index, as: UInt16.self)
        }
        
        var fourBitPacks = get4BitPacksFrom(pointer: mem, count: data.count + 1)
            .map({ UInt8($0) })
            .prefix(packsCount)
        var crcPack: [UInt8] = fourBitPacks.suffix(2)
        
        fourBitPacks.removeLast(2)
        
        crcPack[0] = crcPack[0] << 1 | crcPack[1] >> 3
        
        fourBitPacks.append(crcPack[0])
        
        defer {
            mem.deallocate()
        }
        
        return Array(fourBitPacks)
    }
    
    func create11BitPacks(from entropy: Data, seed: Data) -> [Int] {
        let bytesCount = 80
        let wordsCount = Config.wordsCount
        
        var data = entropy
        
        let crc: UInt8 = seed.firstFiveBits() << 3
        data.append(crc)
        
        let mem = UnsafeMutableRawPointer.allocate(byteCount: bytesCount, alignment: MemoryLayout<UInt8>.alignment)
        for (index, l) in data.enumerated() {
            mem.storeBytes(of: l, toByteOffset: index, as: UInt8.self)
        }
        let elevenBitPacks = get11BitPacksFrom(pointer: mem, byteCount: bytesCount)
            .map({ Int($0) })
            .prefix(wordsCount)
        
        defer {
            mem.deallocate()
        }
        
        return Array(elevenBitPacks)
    }
    
    func createWords(from bitPacks: [Int]) -> [String]? {
        guard let contentsOfFile = importBIP0039Words() else {
            Log("Can't get words from file", module: .mainRepository, severity: .error)
            return nil
        }
        let length = bitPacks.count
        let list = bitPacks.compactMap({ contentsOfFile[safe: $0] })
        guard list.count == length else {
            Log("Incorrect bit packs list count: \(list.count) vs \(length)", module: .mainRepository, severity: .error)
            return nil
        }
        return list
    }
    
    func createCRC(from data: Data) -> UInt8 {
        data.firstFiveBits()
    }
    
    func createSalt(from words: [String]) -> Data? {
        let lastCount = 4
        guard words.count >= lastCount else {
            Log("Can't get 4 words. Words count: \(words.count)", module: .mainRepository, severity: .error)
            return nil
        }
        let words = words.map({ $0.lowercased() })
        let elements = words.suffix(lastCount).joined()
        guard let data = elements.data(using: .utf8) else {
            Log("Can't greate data from words", module: .mainRepository, severity: .error)
            return nil
        }
        return Data(SHA256.hash(data: data))
    }
    
    func hmac(key: String, message: String) -> String? {
        guard let keyData = Data(hexString: key), let messageData = message.data(using: .utf8) else {
            Log("Error converting key or message to data", module: .mainRepository, severity: .error)
            return nil
        }
        let symmetricKey = SymmetricKey(data: keyData)
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
        return authenticationCode.toHEXString()
    }
    
    func normalizeStringIntoHEXData(_ string: String) -> String? {
        let normalized = string.decomposedStringWithCompatibilityMapping
        return normalized.data(using: .utf8)?
            .hexEncodedString()
    }
    
    func generateMasterKey(
        with masterPassword: String,
        seed: Data,
        salt: Data,
        kdfSpec: KDFSpec
    ) -> Data? {
        guard let hexPassword = normalizeStringIntoHEXData(masterPassword) else {
            Log("Can't create HEX from Master Password", module: .mainRepository, severity: .error)
            return nil
        }
        let seed = seed.hexEncodedString()
        let key = "\(seed)\(hexPassword)"
        guard let passwordData = Data(hexString: key) else {
            Log("Can't create HEX from Key", module: .mainRepository, severity: .error)
            return nil
        }
        let variant: Argon2.Variant = {
            switch kdfSpec.kdfType {
            case .argon2d: .d
            case .argon2i: .i
            case .argon2id: .id
            }
        }()
        let partOfSalt = salt[0...Config.wordsCount]
        do  {
            let (rawHash, _) = try Argon2.hash(
                iterations: UInt32(kdfSpec.iterations),
                memoryInKiB: UInt32(kdfSpec.memoryMB * 1024),
                threads: UInt32(kdfSpec.parallelism),
                password: passwordData,
                salt: partOfSalt,
                desiredLength: kdfSpec.hashLength,
                variant: variant,
                version: .v13
            )
            return rawHash
        } catch {
            Log("Can't create key, error: \(error)", module: .mainRepository, severity: .error)
        }
        return nil
    }
    
    var isSecureEnclaveAvailable: Bool {
        SecureEnclave.isAvailable
    }
    
    func createSecureEnclaveAccessControl(needAuth: Bool) -> SecAccessControl? {
        let flags: SecAccessControlCreateFlags
        if needAuth {
            flags =  [.privateKeyUsage, .biometryCurrentSet]
        } else {
            flags = [.privateKeyUsage]
        }
        
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            nil
        ) else {
            Log("Can't create access control for SE keys", module: .mainRepository, severity: .error)
            return nil
        }
        return accessControl
    }
    
    func createSecureEnclavePrivateKey(
        accessControl: SecAccessControl,
        completion: @escaping (Data?) -> Void
    ) {
        DispatchQueue.global().async {
            do {
                let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
                    compactRepresentable: true,
                    accessControl: accessControl,
                    authenticationContext: self.authContext
                )
                DispatchQueue.main.async {
                    completion(privateKey.dataRepresentation)
                }
                return
            } catch {
                Log("Can't get the Secure Enclave private key: \(error)", module: .mainRepository, severity: .error)
            }
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    func createSymmetricKeyFromSecureEnclave(from key: Data) -> SymmetricKey? {
        do {
            let privateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(
                dataRepresentation: key,
                authenticationContext: authContext
            )
            let publicKey = privateKey.publicKey
            let symmetricKey = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
                .x963DerivedSymmetricKey(
                    using: CryptoKit.SHA256.self,
                    sharedInfo: publicKey.rawRepresentation,
                    outputByteCount: 16
                )
            return symmetricKey
        } catch {
            Log("Error while creating symmetric key: \(error)", module: .mainRepository, severity: .error)
            return nil
        }
    }
    
    func createSymmetricKey(from key: Data) -> SymmetricKey {
        SymmetricKey(data: key)
    }
    
    func encrypt(
        _ data: Data,
        key: SymmetricKey
    ) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            Log("Error while encrypting: \(error)", module: .mainRepository)
            return nil
        }
    }
    
    func decrypt(
        _ data: Data,
        key: SymmetricKey
    ) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let result = try AES.GCM.open(sealedBox, using: key)
            return result
        } catch {
            Log("Error while decrypting: \(error)", module: .mainRepository)
            return nil
        }
    }

    func encrypt(_ data: Data, key: SymmetricKey, nonce: Data) -> Data? {
        guard let nonce = try? AES.GCM.Nonce(data: nonce) else {
            Log("Invalid nonce", module: .mainRepository, severity: .error)
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
            return sealedBox.combined
        } catch {
            Log("Error while encrypting: \(error)", module: .mainRepository, severity: .error)
            return nil
        }
    }
    
    func generateRandom(byteCount: Int) -> Data? {
        var randomBytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &randomBytes)
        guard status == errSecSuccess else {
            return nil
        }
        return Data(randomBytes)
    }
    
    var isMasterKeyStored: Bool {
        keychainDataSource.masterKey != nil
    }
    
    func decryptStoredMasterKey() -> MasterKeyEncrypted? {
        guard let biometryKey else {
            Log("Can't get Master Key - no Biometry Key!", module: .mainRepository, severity: .error)
            return nil
        }
        guard let masterKey = keychainDataSource.masterKey else {
            Log("Can't get Master Key - it's nil", module: .mainRepository, severity: .error)
            return nil
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: biometryKey) else {
            Log("Can't get Symmetric Key from Biometry Key while getting Master Key!",
                module: .mainRepository,
                severity: .error
            )
            return nil
        }
        
        guard let decrypted = decrypt(masterKey, key: symm) else {
            Log("Can't get Master Key - error while decrypting!", module: .mainRepository, severity: .error)
            return nil
        }
        
        return decrypted
    }
    
    func saveMasterKey(_ masterKey: MasterKeyEncrypted) {
        guard let biometryKey else {
            Log("Can't save Master Key - no Biometry Key!", module: .mainRepository, severity: .error)
            return
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: biometryKey) else {
            Log(
                "Can't get Symmetric Key from Biometry Key while saving Master Key!",
                module: .mainRepository,
                severity: .error
            )
            return
        }
        
        guard let encrypted = encrypt(masterKey, key: symm) else {
            Log("Can't save Master Key - error while encrypting!", module: .mainRepository, severity: .error)
            return
        }
        
        keychainDataSource.saveMasterKey(encrypted)
    }
    
    func clearMasterKey() {
        keychainDataSource.clearMasterKey()
    }
    
    var trustedKeyFromVault: TrustedKey? {
        guard let appKey else {
            Log("Can't get Secure Key - no App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        guard let trustedKeyEncrypted = selectedVault?.trustedKey else {
            Log("Can't get Trusted Key - it's nil", module: .mainRepository, severity: .error)
            return nil
        }
        
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        
        guard let decrypted = decrypt(trustedKeyEncrypted, key: symm) else {
            Log("Can't get Trusted Key - error while decrypting!", module: .mainRepository, severity: .error)
            return nil
        }
        
        return decrypted
    }
    
    var appKey: AppKey? {
        keychainDataSource.appKey
    }
    
    func saveAppKey(_ data: AppKey) {
        keychainDataSource.saveAppKey(data)
    }
    
    func clearAppKey() {
        keychainDataSource.clearAppKey()
    }
    
    var biometryKey: BiometryKey? {
        keychainDataSource.biometryKey
    }
    
    func saveBiometryKey(_ data: BiometryKey) {
        keychainDataSource.saveBiometryKey(data)
    }
    
    func clearBiometryKey() {
        keychainDataSource.clearBiometryKey()
    }
    
    var trustedKey: TrustedKey? {
        guard let appKey else {
            Log("Can't get Trusted Key - no App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        
        guard let empheralTrustedKey = _empheralTrustedKey else {
            Log("Can't get Trusted Key - it's nil", module: .mainRepository, severity: .error)
            return nil
        }
        
        guard let decrypted = decrypt(empheralTrustedKey, key: symm) else {
            Log("Can't get Trusted Key - error while decrypting!", module: .mainRepository, severity: .error)
            return nil
        }
        
        return decrypted
    }
    
    func setTrustedKey(_ data: TrustedKey) {
        guard let appKey else {
            Log("Can't save Trusted Key - no App Key!", module: .mainRepository, severity: .error)
            return
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return
        }
        
        guard let encrypted = encrypt(data, key: symm) else {
            Log("Can't save Secure Key - error while encrypting", module: .mainRepository, severity: .error)
            return
        }
        
        _empheralTrustedKey = encrypted
    }
    
    func clearTrustedKey() {
        _empheralTrustedKey = nil
    }
    
    var secureKey: SecureKey? {
        guard let appKey else {
            Log("Can't get Secure Key - no App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        
        guard let empheralSecureKey = _empheralSecureKey else {
            Log("Can't get Secure Key - it's nil", module: .mainRepository, severity: .error)
            return nil
        }
        
        guard let decrypted = decrypt(empheralSecureKey, key: symm) else {
            Log("Can't get Secure Key - error while decrypting!", module: .mainRepository, severity: .error)
            return nil
        }
        
        return decrypted
    }
    
    func setSecureKey(_ data: SecureKey) {
        guard let appKey else {
            Log("Can't save Secure Key - no App Key!", module: .mainRepository, severity: .error)
            return
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return
        }
        
        guard let encrypted = encrypt(data, key: symm) else {
            Log("Can't save Secure Key - error while encrypting", module: .mainRepository, severity: .error)
            return
        }
        
        _empheralSecureKey = encrypted
    }
    
    func clearSecureKey() {
        _empheralSecureKey = nil
    }
    
    var cachedExternalKey: SymmetricKey? {
        if let _externalKeySymm {
            return _externalKeySymm
        }
        guard let externalKey else {
            return nil
        }
        return createSymmetricKey(from: externalKey)
    }
    
    var externalKey: ExternalKey? {
        guard let appKey else {
            Log("Can't get External Key - no App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        
        guard let empheralExteralKey = _empheralExteralKey else {
            Log("Can't get External Key - it's nil", module: .mainRepository, severity: .error)
            return nil
        }
        
        guard let decrypted = decrypt(empheralExteralKey, key: symm) else {
            Log("Can't get External Key - error while decrypting!", module: .mainRepository, severity: .error)
            return nil
        }
        
        return decrypted
    }
    
    func setExternalKey(_ data: ExternalKey) {
        guard let appKey else {
            Log("Can't save External Key - no App Key!", module: .mainRepository, severity: .error)
            return
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return
        }
        
        guard let encrypted = encrypt(data, key: symm) else {
            Log("Can't save External Key - error while encrypting", module: .mainRepository, severity: .error)
            return
        }
        
        _empheralExteralKey = encrypted
    }
    
    func clearExternalKey() {
        _empheralExteralKey = nil
    }
    
    var hasEncryptionReference: Bool {
        keychainDataSource.encryptionReference != nil
    }
    
    func saveEncryptionReference(_ deviceID: DeviceID, masterKey: MasterKey) {
        guard let appKey else {
            Log("Can't save Encryption Reference - no App Key!", module: .mainRepository, severity: .error)
            return
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return
        }
        
        let symmMK = createSymmetricKey(from: masterKey)
        guard let data = deviceID.exportString().data(using: .utf8), let encryptedMK = encrypt(data, key: symmMK) else {
            Log("Can't encrypt Encryption Reference using Master Key", module: .mainRepository, severity: .error)
            return
        }
        guard let encrypted = encrypt(encryptedMK, key: symm) else {
            Log("Can't encrypt Encryption Reference using App Key", module: .mainRepository, severity: .error)
            return
        }
        keychainDataSource.saveEncryptionReference(encrypted)
    }
    
    func verifyEncryptionReference(using masterKey: MasterKey, with deviceID: DeviceID) -> Bool {
        guard let appKey else {
            Log("Can't verify Encryption Reference - no App Key!", module: .mainRepository, severity: .error)
            return false
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return false
        }
        
        let symmMK = createSymmetricKey(from: masterKey)
        guard let savedData = keychainDataSource.encryptionReference,
              let decrypted = decrypt(savedData, key: symm)
        else {
            Log("Can't decrypt Encryption Reference using App Key", module: .mainRepository, severity: .error)
            return false
        }
        guard let decryptedMK = decrypt(decrypted, key: symmMK),
              let decryptedDeviceID = String(data: decryptedMK, encoding: .utf8)
        else {
            Log("Can't decrypt Encryption Reference using Master Key. Wrong Master Key", module: .mainRepository)
            return false
        }
        return decryptedDeviceID == deviceID.exportString()
    }
    
    func clearEncryptionReference() {
        keychainDataSource.clearEncryptionReference()
    }
    
    var hasMasterKeyEntropy: Bool {
        keychainDataSource.masterKeyEntropy != nil
    }
    
    var masterKeyEntropy: Entropy? {
        guard let appKey, let mke = keychainDataSource.masterKeyEntropy else { return nil }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return nil
        }
        return decrypt(mke, key: symm)
    }
    
    func saveMasterKeyEntropy(_ mkEntropy: Entropy) {
        guard let appKey else {
            Log("Can't save Master Key Entropy - no App Key!", module: .mainRepository, severity: .error)
            return
        }
        guard let symm = createSymmetricKeyFromSecureEnclave(from: appKey) else {
            Log("Can't get Symmetric Key from App Key!", module: .mainRepository, severity: .error)
            return
        }
        guard let encrypted = encrypt(mkEntropy, key: symm) else {
            Log("Can't encrypt Master Key Entropy", module: .mainRepository, severity: .error)
            return
        }
        keychainDataSource.saveMasterKeyEntropy(encrypted)
    }
    
    func clearMasterKeyEntropy() {
        keychainDataSource.clearMasterKeyEntropy()
    }
    
    var seed: Seed? {
        _empheralSeed
    }
    
    func setSeed(_ data: Seed) {
        _empheralSeed = data
    }
    
    func clearSeed() {
        _empheralSeed = nil
    }
    
    var entropy: Entropy? {
        _empheralEntropy
    }
    
    func setEntropy(_ entropy: Entropy) {
        _empheralEntropy = entropy
    }
    
    func clearEntropy() {
        _empheralEntropy = nil
    }
    
    var words: [String]? {
        _empheralWords
    }
    
    func setWords(_ words: [String]) {
        _empheralWords = words
    }
    
    func clearWords() {
        _empheralWords = nil
    }
    
    var salt: Data? {
        _empheralSalt
    }
    
    func setSalt(_ salt: Data) {
        _empheralSalt = salt
    }
    
    func clearSalt() {
        _empheralSalt = nil
    }
    
    var masterPassword: MasterPassword? {
        _empheralMasterPassword
    }
    
    func setMasterPassword(_ masterPassword: MasterPassword) {
        _empheralMasterPassword = masterPassword
    }
    
    func clearMasterPassword() {
        _empheralMasterPassword = nil
    }
    
    var empheralMasterKey: MasterKey? {
        _ephemeralMasterKey
    }
    
    func setEmpheralMasterKey(_ masterKey: MasterKey) {
        _ephemeralMasterKey = masterKey
    }
    
    func clearEmpheralMasterKey() {
        _ephemeralMasterKey = nil
    }
    
    func clearAllEmphemeral() {
        clearTrustedKey()
        clearSecureKey()
        clearExternalKey()
        
        clearCachedKeys()
        
        clearSeed()
        clearEntropy()
        clearWords()
        clearSalt()
        clearEmpheralMasterKey()
        
        clearVault()
    }
    
    func generateTrustedKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String? {
        hmac(key: masterKey, message: vaultID.exportString() + "/tKey")
    }
    
    func generateSecureKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String? {
        hmac(key: masterKey, message: vaultID.exportString() + "/sKey")
    }
    
    func generateExternalKeyForVaultID(_ vaultID: VaultID, using masterKey: String) -> String? {
        hmac(key: masterKey, message: vaultID.exportString() + "/eKey")
    }
    
    func generateExchangeSeedHash(_ vaultID: VaultID, using seed: Data) -> String? {
        hmac(key: seed.hexEncodedString(), message: vaultID.exportString() + "/eKey")
    }
    
    func getKey(isPassword: Bool, protectionLevel: PasswordProtectionLevel) -> SymmetricKey? {
        switch (isPassword, protectionLevel) {
        case (false, .normal), (false, .confirm), (true, .normal):
            if let _trustedKeySymm {
                return _trustedKeySymm
            }
            guard let trustedKey else {
                Log("Can't get trusted key for determining protection level", module: .mainRepository, severity: .error)
                return nil
            }
            return createSymmetricKey(from: trustedKey)
        case (false, .topSecret), (true, .confirm), (true, .topSecret):
            if let _secureKeySymm {
                return _secureKeySymm
            }
            guard let secureKey else {
                Log("Can't get secure key for determining protection level", module: .mainRepository, severity: .error)
                return nil
            }
            return createSymmetricKey(from: secureKey)
        }
    }
    
    func preparedCachedKeys() {
        guard let trustedKey, let secureKey, let externalKey else {
            Log(
                "Can't prepare cached keys! This will degredate the performance",
                module: .mainRepository,
                severity: .error
            )
            return
        }
        _trustedKeySymm = createSymmetricKey(from: trustedKey)
        _secureKeySymm = createSymmetricKey(from: secureKey)
        _externalKeySymm = createSymmetricKey(from: externalKey)
    }
    
    func clearCachedKeys() {
        _trustedKeySymm = nil
        _secureKeySymm = nil
        _externalKeySymm = nil
    }
    
    func importBIP0039Words() -> [String]? {
        guard let filePath = Bundle(for: MainRepositoryImpl.self).path(forResource: "BIP-0039_English", ofType: "txt"),
              let url = URL(string: "file://\(filePath)")
        else {
            Log("Can't create BIP 0039 file URL", module: .mainRepository, severity: .error)
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                Log("Can't read contents of BIP 0039 file", module: .mainRepository, severity: .error)
                return nil
            }
            let val: [String] = content.split(separator: "\n", omittingEmptySubsequences: true).map({ String($0) })
            return val
        } catch {
            Log("Error while opening the file BIP-0039_English.txt \(error)", module: .mainRepository, severity: .error)
        }
        
        return nil
    }
    
    func convertWordsTo4BitPacksAndCRC(_ words: [String]) -> (bitPacks: Data, crc: UInt8)? {
        guard let decimals = convertWordsToDecimal(words) else {
            Log("Can't get decimals from words", module: .mainRepository, severity: .error)
            return nil
        }
        let split11bits = create11BitPacks(from: decimals)
        var fourBitPacks = create4BitPacksFrom11BitPacks(split11bits)
        guard let crc = fourBitPacks.last else {
            Log("Can't get crc from four bit packs", module: .mainRepository, severity: .error)
            return nil
        }
        fourBitPacks.removeLast()

        let str = Data(fourBitPacks).hexEncodedStringFrom4Bits()
        guard let dataFromHexString = Data(hexString: str) else {
            Log("Error while creating data from hex string", module: .mainRepository, severity: .error)
            return nil
        }
        return (bitPacks: dataFromHexString, crc: crc)
    }
    
    func createSeedHashHexForExport() -> String? {
        guard let seed, let vaultID = selectedVault?.vaultID else {
            Log("Error while creating SeedHashHexForExport - no seed or vaultID", module: .mainRepository, severity: .error)
            return nil
        }
        guard let seedHash = generateExchangeSeedHash(vaultID, using: seed),
              let baseString = Data(hexString: seedHash)?.base64EncodedString()
        else {
            return nil
        }
        return baseString
    }
    
    func createReferenceForExport() -> String? {
        guard let externalKey, let vaultID = selectedVault?.vaultID else {
            Log("Error while creating createReferenceForExport - no externalKey or vaultID", module: .mainRepository, severity: .error)
            return nil
        }
        guard let data = vaultID.exportString().data(using: .utf8)
        else {
            return nil
        }
        let key = createSymmetricKey(from: externalKey)
        return encrypt(data, key: key)?
            .base64EncodedString()
    }
    
    private func groupInto11Bits(_ bytes: [UInt8]) -> [UInt16] {
        var bitStream = bytes.flatMap { byte in
            (0..<8).map { (byte >> $0) & 1 }
        }
        
        var result: [UInt16] = []
        
        while bitStream.count >= 11 {
            let group = bitStream.prefix(11)
            let value = group.enumerated().reduce(0) { result, element in
                result | (UInt16(element.element) << element.offset)
            }
            result.append(value)
            bitStream = Array(bitStream.dropFirst(11))
        }
        
        return result
    }
    
    private func get11BitPacksFrom(pointer: UnsafeMutableRawPointer, byteCount: Int) -> [UInt16] {
        let buffer = UnsafeBufferPointer(start: pointer.assumingMemoryBound(to: UInt8.self), count: byteCount)
        
        var result: [UInt16] = []
        var bitBuffer: UInt32 = 0
        var bitsAvailable = 0
        
        for byte in buffer {
            bitBuffer = (bitBuffer << 8) | UInt32(byte)
            bitsAvailable += 8
            
            while bitsAvailable >= 11 {
                bitsAvailable -= 11
                let value = UInt16((bitBuffer >> bitsAvailable) & 0x7FF)
                result.append(value)
            }
        }
        
        return result
    }
    
    private func get4BitPacksFrom(pointer: UnsafeMutableRawPointer, count: Int) -> [UInt8] {
        let buffer = UnsafeBufferPointer(start: pointer.assumingMemoryBound(to: UInt16.self), count: count)
        
        var result: [UInt8] = []
        var bitBuffer: UInt32 = 0
        var bitsAvailable = 0
                
        for byte in buffer {
            bitBuffer = (bitBuffer << 11) | UInt32(byte)
            bitsAvailable += 11
            
            while bitsAvailable >= 4 {
                bitsAvailable -= 4
                let value = UInt8((bitBuffer >> bitsAvailable) & 0xF)
                result.append(value)
            }
        }
        
        return result
    }
}

private extension Data {
    func firstFiveBits() -> UInt8 {
        guard let firstByte = self.first else {
            return 0
        }
        
        return firstByte >> 3
    }
}
