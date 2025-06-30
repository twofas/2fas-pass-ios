// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public enum ConnectAction {
    case passwordRequest(PasswordData)
    case add(PasswordDataChangeRequest)
    case update(PasswordData, PasswordDataChangeRequest)
    case delete(PasswordData)
}

public enum ConnectActionType: String, Codable {
    case passwordRequest
    case updateLogin
    case newLogin
    case deleteLogin
}

struct ConnectActionRequest<T>: Codable where T: Codable {
    let type: ConnectActionType
    let data: T
}

struct ConnectActioRequestType: Codable {
    let type: ConnectActionType
}

struct ConnectActionDeleteRequestData: Codable {
    let loginId: UUID
}

struct ConnectActionPasswordRequestData: Codable {
    let loginId: UUID
}

struct ConnectActionAddRequestData: Codable {
    let notificationId: String
    let url: String
    let username: String?
    let passwordEnc: Data?
    let usernamePasswordMobile: Bool
}

struct ConnectActionUpdateRequestData: Codable {
    let id: UUID
    let securityType: Int
    let name: String?
    let username: String?
    let notificationId: String
    let passwordMobile: Bool?
    let usernameMobile: Bool?
    let passwordEnc: Data?
    let notes: String?
    let uris: [URI]?
    
    struct URI: Codable {
        let text: String
        let matcher: Int
    }
}

struct ConnectActionPasswordData: Codable {

    enum Status: String, Codable {
        case accept
    }
    
    let type: ConnectActionType
    let status: Status
    let passwordEnc: Data
}

struct ConnectActionItemData: Codable {

    enum Status: String, Codable {
        case added
        case updated
        case addedInT1
        case cancel
        case accept
    }
    
    let type: ConnectActionType
    let status: Status
    let login: ConnectLogin?
}
