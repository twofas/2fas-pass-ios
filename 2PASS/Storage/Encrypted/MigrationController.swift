//
//  MigrationController.swift
//  2PASS
//
//  Created by Maciej Szewczyk on 13/07/2025.
//  Copyright © 2025 Two Factor Authentication Service, Inc. All rights reserved.
//

import Common

public enum EncryptionKey {
    case vault(VaultID, ItemProtectionLevel)
    case appKey
    case metadataKey
}

public final class MigrationController {

    public static var current: MigrationController?

    private let _encrypt: (Data, EncryptionKey) -> Data?
    private let _decrypt: (Data, EncryptionKey) -> Data?

    public init(
        encrypt: @escaping (Data, EncryptionKey) -> Data?,
        decrypt: @escaping (Data, EncryptionKey) -> Data?
    ) {
        self._encrypt = encrypt
        self._decrypt = decrypt
    }

    func encrypt(_ data: Data, using key: EncryptionKey) -> Data? {
        _encrypt(data, key)
    }

    func decrypt(_ data: Data, using key: EncryptionKey) -> Data? {
        _decrypt(data, key)
    }
}
