// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol ViewPasswordModuleInteracting: AnyObject {
    func fetchPassword(for passwordID: PasswordID) -> PasswordData?
    func fetchTags(for tagIDs: [ItemTagID]) -> [ItemTagData]
    func decryptPassword(for passwordID: PasswordID) -> String?
    func copy(_ str: String)
    func fetchIconImage(from url: URL) async throws -> Data
    func normalizedURL(for uri: PasswordURI) -> URL?
}

final class ViewPasswordModuleInteractor {
    private let passwordInteractor: PasswordInteracting
    private let systemInteractor: SystemInteracting
    private let fileIconInteractor: FileIconInteracting
    private let uriInteractor: URIInteracting
    private let tagInteractor: TagInteracting
    
    init(
        passwordInteractor: PasswordInteracting,
        systemInteractor: SystemInteracting,
        fileIconInteractor: FileIconInteracting,
        uriInteractor: URIInteracting,
        tagInteractor: TagInteracting
    ) {
        self.passwordInteractor = passwordInteractor
        self.systemInteractor = systemInteractor
        self.fileIconInteractor = fileIconInteractor
        self.uriInteractor = uriInteractor
        self.tagInteractor = tagInteractor
    }
}

extension ViewPasswordModuleInteractor: ViewPasswordModuleInteracting {
    func fetchPassword(for passwordID: PasswordID) -> PasswordData? {
        passwordInteractor.getPassword(for: passwordID, checkInTrash: false)
    }
    
    func decryptPassword(for passwordID: PasswordID) -> String? {
        switch passwordInteractor.getPasswordEncryptedContents(for: passwordID, checkInTrash: false) {
        case .success(let password): return password
        case .failure: return nil
        }
    }
    
    func copy(_ str: String) {
        systemInteractor.copyToClipboard(str)
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
    
    func normalizedURL(for uri: PasswordURI) -> URL? {
        guard let normalizedString = uriInteractor.normalize(uri.uri), let url = URL(string: normalizedString) else {
            return nil
        }
        return url
    }
    
    func fetchTags(for tagIDs: [ItemTagID]) -> [ItemTagData] {
        tagInteractor.getTags(by: tagIDs)
    }
}
