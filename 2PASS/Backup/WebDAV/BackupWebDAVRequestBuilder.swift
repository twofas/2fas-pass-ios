// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

final class BackupWebDAVRequestBuilder {
    enum RequestType {
        case get(url: URL, login: String?, password: String?)
        case delete(url: URL, login: String?, password: String?)
        case write(url: URL, fileContents: Data, login: String?, password: String?)
        case move(url: URL, destination: URL, login: String?, password: String?)
    }
    
    func buildRequest(of type: RequestType) -> URLRequest {
        switch type {
        case .get(let url, let login, let password):
            createGetRequest(url: url, login: login, password: password)
        case .delete(let url, let login, let password):
            createDeleteRequest(url: url, login: login, password: password)
        case .write(let url, let fileContents, let login, let password):
            createWriteRequest(url: url, fileContents: fileContents, login: login, password: password)
        case .move(let url, let destination, let login, let password):
            createMoveRequest(url: url, destination: destination, login: login, password: password)
        }
    }
}

private extension BackupWebDAVRequestBuilder {
    func createGetRequest(url: URL, login: String?, password: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        authorize(&request, login: login, password: password)
        
        return request
    }
    
    func createDeleteRequest(url: URL, login: String?, password: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        authorize(&request, login: login, password: password)
        
        return request
    }
    
    func createWriteRequest(
        url: URL,
        fileContents: Data,
        login: String?,
        password: String?
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        authorize(&request, login: login, password: password)
        
        request.httpBody = fileContents
        
        return request
    }
    
    func createMoveRequest(url: URL, destination: URL, login: String?, password: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "MOVE"
        request.setValue(destination.absoluteString, forHTTPHeaderField: "Destination")
        request.setValue("T", forHTTPHeaderField: "Overwrite")
        
        authorize(&request, login: login, password: password)
        
        return request
    }
    
    func authorize(_ request: inout URLRequest, login: String?, password: String?) {
        let login = login ?? ""
        let password = password ?? ""
        let str = "\(login):\(password)"
        guard let data = str.data(using: .utf8) else {
            Log("Can't authorize URL Request", module: .backup)
            return
        }
        let base64String = data.base64EncodedString()
        request.setValue("Basic \(base64String)", forHTTPHeaderField: "Authorization")
    }
}
