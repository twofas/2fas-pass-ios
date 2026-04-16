// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public typealias SecureNoteItemData          = _ItemData<SecureNoteContent>
public typealias SecureNoteItemDecryptedData = _ItemData<SecureNoteDecryptedContent>

public typealias SecureNoteContent          = _SecureNoteContent<Encrypted>
public typealias SecureNoteDecryptedContent = _SecureNoteContent<Decrypted>

public struct _SecureNoteContent<State: EncryptionState>: ItemContent {

    public static var contentType: ItemContentType { .secureNote }
    public static var contentVersion: Int { 1 }

    public let name: String?
    public let text: State.SecureField?
    public let additionalInfo: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case text = "s_text"
        case additionalInfo
    }
}

extension SecureNoteContent {

    public init(name: String?, text: Data?, additionalInfo: String?) {
        self.name = name
        self.text = text
        self.additionalInfo = additionalInfo
    }
}

extension SecureNoteDecryptedContent {

    public init(name: String?, text: String?, additionalInfo: String?) {
        self.name = name
        self.text = text
        self.additionalInfo = additionalInfo
    }
}

extension ItemData {

    public var asSecureNote: SecureNoteItemData? {
        switch self {
        case .secureNote(let secureNoteItem): secureNoteItem
        default: nil
        }
    }
}

extension ItemDecryptedData {

    public var asSecureNote: SecureNoteItemDecryptedData? {
        switch self {
        case .secureNote(let secureNoteItem): secureNoteItem
        default: nil
        }
    }
}
