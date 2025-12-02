// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public enum ConnectAction {
    case sifRequest(ItemData)
    case changeRequest(ItemChangeRequest)
    case delete(ItemData)
    case sync
}

extension ConnectSchemaV1 {
 
    struct ConnectActionRequest<T>: Codable where T: Codable {
        let type: ConnectActionType
        let data: T
    }

    struct ConnectActioRequestType: Codable {
        let type: ConnectActionType
    }
    
    enum ConnectActionType: String, Codable {
        case passwordRequest
        case updateLogin
        case newLogin
        case deleteLogin
    }
    
    struct ConnectActionPasswordData: Codable {

        enum Status: String, Codable {
            case accept
        }
        
        let type: ConnectActionType
        let status: Status
        let passwordEnc: Data
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
        let usernamePasswordMobile: Bool?
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
}

extension ConnectSchemaV2 {
    
    typealias ConnectActionSifRequest = ConnectActionRequest<ActionRequestsData.ItemMetadata>
    
    typealias ConnectActionAddDataRequest = ConnectActionRequest<ActionRequestsData.AddItemMetadata>
    typealias ConnectActionUpdateDataRequest = ConnectActionRequest<ActionRequestsData.ItemMetadata>
    typealias ConnectActionDeleteDataRequest = ConnectActionRequest<ActionRequestsData.ItemMetadata>
    
    typealias ConnectActionAddLoginRequest = ConnectActionRequest<ActionRequestsData.AddItemData<ActionRequestsContentData.AddLogin>>
    typealias ConnectActionUpdateLoginRequest = ConnectActionRequest<ActionRequestsData.ItemData<ActionRequestsContentData.UpdateLogin>>
    typealias ConnectActionAddSecureNoteRequest = ConnectActionRequest<ActionRequestsData.AddItemData<ActionRequestsContentData.AddSecureNote>>
    typealias ConnectActionUpdateSecureNoteRequest = ConnectActionRequest<ActionRequestsData.ItemData<ActionRequestsContentData.UpdateSecureNote>>

    enum SupportedFeatures: String {
        case secureNote = "items.secureNote"
    }
    
    struct ConnectActioRequestType: Decodable {
        let type: ConnectActionType
    }
    
    struct ConnectActionRequest<T>: Decodable where T: Decodable {
        let type: ConnectActionType
        let data: T
    }
    
    enum ActionRequestsData {
        
        struct AddItemMetadata: Decodable {
            let contentType: String
        }
        
        struct ItemMetadata: Decodable {
            let vaultId: UUID
            let itemId: UUID
            let contentType: String
            let sifFetched: Bool?
            let securityType: Int?
        }
        
        struct AddItemData<T>: Decodable where T: Decodable {
            let content: T
        }
        
        struct ItemData<T>: Decodable where T: Decodable {
            let content: T
            let tags: [UUID]?
        }
    }
    
    enum ActionRequestsContentData {
        
        struct Field: Decodable {
            enum Action: String, Decodable {
                case set
                case generate
            }
            
            let value: String?
            let action: Action
        }
        
        struct SecureField: Decodable {
            enum Action: String, Decodable {
                case set
                case generate
            }
            
            let value: Data?
            let action: Action
        }
        
        struct AddLogin: Decodable {
            private enum CodingKeys: String, CodingKey {
                case url
                case username
                case password = "s_password"
            }

            let url: String
            let username: Field
            let password: SecureField
        }
        
        struct UpdateLogin: Decodable {
            private enum CodingKeys: String, CodingKey {
                case name
                case username
                case password = "s_password"
                case notes
                case uris
            }

            let name: String?
            let username: Field?
            let password: SecureField?
            let notes: String?
            let uris: [ConnectURI]?
        }

        struct AddSecureNote: Decodable {
            private enum CodingKeys: String, CodingKey {
                case name
                case text = "s_text"
            }

            let name: String
            let text: Data
        }

        struct UpdateSecureNote: Decodable {
            private enum CodingKeys: String, CodingKey {
                case name
                case text = "s_text"
                case additionalInfo
            }

            let name: String?
            let text: Data?
            let additionalInfo: String?
        }
    }
    
    enum ConnectActionType: String, Codable {
        case sifRequest
        case addData
        case updateData
        case deleteData
        case fullSync
    }
        
    struct ConnectActionResponseData<T>: Encodable where T: Encodable {
        typealias Status = ConnectSchemaV1.ConnectActionItemData.Status

        let type: ConnectActionType
        let status: Status
        let expireInSeconds: Int?
        let data: T?
        let tags: [ConnectTag]?
    }
    
    struct SyncData: Encodable {
        let type: ConnectActionType
        let status: ConnectSchemaV1.ConnectActionItemData.Status
        let totalChunks: Int
        let totalSize: Int
        let sha256GzipVaultDataEnc: String
    }
}

struct ConnectActionEmptyResponseData: Encodable {}

extension ConnectSchemaV2.ConnectActionResponseData where T == ConnectActionEmptyResponseData {
    
    init(type: ConnectSchemaV2.ConnectActionType, status: Status) {
        self.type = type
        self.status = status
        self.expireInSeconds = nil
        self.data = nil
        self.tags = nil
    }
}
