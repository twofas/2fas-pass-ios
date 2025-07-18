//
//  MigrationController.swift
//  2PASS
//
//  Created by Maciej Szewczyk on 13/07/2025.
//  Copyright © 2025 Two Factor Authentication Service, Inc. All rights reserved.
//

import Common

public final class MigrationController {
    
    public static var current: MigrationController?
    
    private let setupKeys: (UUID) -> Void
    private let encrypt: (Data, ItemProtectionLevel) -> Data?
    private let decrypt: (Data, ItemProtectionLevel) -> Data?
    
    public init(
        setupKeys: @escaping (UUID) -> Void,
        encrypt: @escaping (Data, ItemProtectionLevel) -> Data?,
        decrypt: @escaping (Data, ItemProtectionLevel) -> Data?
    ) {
        self.setupKeys = setupKeys
        self.encrypt = encrypt
        self.decrypt = decrypt
    }
    
    func setupKeys(vaultID: UUID) {
        setupKeys(vaultID)
    }
    
    func encrypt(_ data: Data, protectionLevel: ItemProtectionLevel) -> Data? {
        encrypt(data, protectionLevel)
    }
    
    func decrypt(_ data: Data, protectionLevel: ItemProtectionLevel) -> Data? {
        decrypt(data, protectionLevel)
    }
}
