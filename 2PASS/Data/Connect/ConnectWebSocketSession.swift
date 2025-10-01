// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public enum ConnectWebSocketError: Error {
    case webSocketIsNotStarted
    case badResponse
    case wrongResponseId
    case wrongResponseAction
    case missingExpectedPayload
    case closeWithError
    case webSocketClosed
    case appUpdateRequired
    case browserExtensionUpdateRequired
}

final class ConnectWebSocketSession: NSObject {
    
    private let deviceName: String
    private let appVersion: String

    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()
    private let expectedResponseStorage = ExpectedResponseStorage()
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Error>?
    private var onClose: Callback?
    
    init(baseURL: URL, sessionId: String, deviceName: String, appVersion: String) {
        self.deviceName = deviceName
        self.appVersion = appVersion
                
        let session = URLSession(configuration: .default)
        let url = URL(string: "\(baseURL.absoluteString)\(sessionId)")!
        var request = URLRequest(url: url)
        request.setValue("2FAS-Pass", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        webSocketTask = session.webSocketTask(with: request)
        
        super.init()
        
        webSocketTask?.delegate = self
    }
    
    func onClose(_ action: @escaping Callback) {
        self.onClose = action
    }

    func start() {
        webSocketTask?.resume()
        receive()
    }
    
    func close() {
        Task {
            await expectedResponseStorage.finish(with: ConnectWebSocketError.webSocketClosed)
        }
    
        if let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: 3005) {
            webSocketTask?.cancel(with: closeCode, reason: nil)
        } else {
            webSocketTask?.cancel(with: .goingAway, reason: nil)
        }
    }
    
    func send<Request>(_ request: Request) async throws where Request: ConnectRequestWithoutResponse {
        guard let webSocketTask else {
            throw ConnectWebSocketError.webSocketIsNotStarted
        }
        
        try await send(request, using: webSocketTask)
    }
    
    func send<Request>(_ request: Request) async throws where Request: ConnectRequestExpectedResponse, Request.ResponsePayload == ConnectMessagePayloadEmpty {
        guard let webSocketTask else {
            throw ConnectWebSocketError.webSocketIsNotStarted
        }
        
        try await send(request, using: webSocketTask)
        _ = try await receive(validator: request.validateResponse, requestId: request.id)
    }
    
    func send<Request>(_ request: Request) async throws -> Request.ResponsePayload where Request: ConnectRequestExpectedResponse {
        guard let webSocketTask else {
            throw ConnectWebSocketError.webSocketIsNotStarted
        }
        
        try await send(request, using: webSocketTask)
        let response = try await receive(validator: request.validateResponse, requestId: request.id)
        
        guard let payload = response.payload else {
            throw ConnectWebSocketError.missingExpectedPayload
        }
        
        return payload
    }
    
    func validateSchemeVersion(_ version: Int) throws(ConnectWebSocketError) {
        if version > Config.connectSchemaVersion {
            throw ConnectWebSocketError.appUpdateRequired
        } else if version < Config.connectSchemaVersion - 1 { // support 2 scheme versions of browser extension
            throw ConnectWebSocketError.browserExtensionUpdateRequired
        }
    }
    
    private func send<Request>(_ request: Request, using webSocketTask: URLSessionWebSocketTask) async throws where Request: ConnectRequest {
        guard webSocketTask.closeCode == .invalid else {
            throw ConnectWebSocketError.webSocketClosed
        }
                
        let message = makeMessage(for: request)
        let requestData = try jsonEncoder.encode(message)
        
        try await withTaskCancellationHandler {
            try await webSocketTask.send(.data(requestData))
        } onCancel: {
            self.close()
        }
    }
    
    private func receive<ResponsePayload>(
        validator: (ConnectMessage<ResponsePayload>) throws -> Void,
        requestId: UUID) async throws
    -> ConnectMessage<ResponsePayload> where ResponsePayload: ConnectMessagePayload {
        let data = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    await expectedResponseStorage.set(id: requestId, continuation: continuation)
                }
            }
        } onCancel: {
            self.close()
        }

        let responseMessage = try jsonDecoder.decode(ConnectMessage<ResponsePayload>.self, from: data)
        
        guard responseMessage.id == requestId else {
            throw ConnectWebSocketError.wrongResponseId
        }
        
        try validator(responseMessage)
        
        return responseMessage
    }
    
    private func receive() {
        receiveTask = Task {
            let result = try await webSocketTask?.receive()
            
            switch result {
            case .string(let stringData):
                guard let jsonData = stringData.data(using: .utf8) else {
                    throw ConnectWebSocketError.badResponse
                }

                let responseMessage = try jsonDecoder.decode(GenericConnectMessage.self, from: jsonData)
                
                let expectedResponseId = await expectedResponseStorage.id

                do {
                    try validateSchemeVersion(responseMessage.scheme)
                } catch {
                    await expectedResponseStorage.finish(with: error)
                }
                
                if expectedResponseId == UUID(uuidString: responseMessage.id) {
                    await expectedResponseStorage.finish(with: jsonData)
                } else if responseMessage.action == .closeWithError {
                    await expectedResponseStorage.finish(with: ConnectWebSocketError.closeWithError)
                } else {
                    await expectedResponseStorage.finish(with: ConnectWebSocketError.wrongResponseId)
                }
                                
            default:
                break
            }
            
            receive()
        }
    }
    
    private func makeMessage<Request>(for request: Request) -> ConnectMessage<Request.Payload> where Request: ConnectRequest {
        ConnectMessage(
            scheme: Config.Connect.schemaVersion,
            origin: deviceName,
            originVersion: appVersion,
            id: request.id,
            action: request.action,
            payload: request.payload
        )
    }
}

extension ConnectWebSocketSession: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        close()
        onClose?()
    }
}

extension ConnectWebSocketSession {
    
    private actor ExpectedResponseStorage {
        private(set) var id: UUID?
        private(set) var continuation: CheckedContinuation<Data, Error>?
        
        func set(id: UUID, continuation: CheckedContinuation<Data, Error>) {
            self.id = id
            self.continuation = continuation
        }
        
        func finish(with data: Data) {
            continuation?.resume(returning: data)
            clear()
        }
        
        func finish(with error: Error) {
            continuation?.resume(throwing: error)
            clear()
        }
        
        func clear() {
            id = nil
            continuation = nil
        }
    }
}
