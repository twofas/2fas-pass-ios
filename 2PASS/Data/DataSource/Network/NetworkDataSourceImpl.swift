// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

final class NetworkDataSourceImpl {
    private let queue: DispatchQueue
    private let session: URLSession
    private let configuration: URLSessionConfiguration = {
        var headers: [String: String] = [:]
        
        headers["Accept-Encoding"] = "gzip;q=1.0, compress;q=0.5"
        
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = headers
        
        config.requestCachePolicy = .reloadIgnoringCacheData
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.networkServiceType = .responsiveData
        config.waitsForConnectivity = false
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsCellularAccess = true
        
        return config
    }()
    
    init() {
        self.queue = DispatchQueue(label: "io.twopass.response-queue", qos: .userInitiated, attributes: [.concurrent])
        self.session = URLSession(configuration: configuration)
    }
}

extension NetworkDataSourceImpl: NetworkDataSource {
    func fetchFile(from url: URL, completion: @escaping (Result<Data, NetworkError>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        queue.async { [weak self] in
            guard let self else { return }
            let dataTask = self.session.dataTask(
                with: request
            ) { [weak self] data, response, error in
                guard self?.noErrorOccured(data, error, completion: completion) == true else { return }
                guard let data else {
                    self?.otherErrorCall(error: nil, completion: completion)
                    return
                }
                DispatchQueue.main.async {
                    completion(.success(data))
                }
            }
            dataTask.resume()
        }
    }
}

private extension NetworkDataSourceImpl {
    func noErrorOccured<T>(
        _ data: Data?,
        _ error: Error?,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) -> Bool {
        if let nsError = error, data == nil {
            let error = nsError as NSError
            if error.code == NSURLErrorSecureConnectionFailed {
                otherErrorCall(error: error, completion: completion)
            } else if error.code.isNetworkError {
                noInternetCall(error: error, completion: completion)
            } else if error.code.isServerError {
                serverErrorCall(error: error, completion: completion)
            } else {
                otherErrorCall(error: error, completion: completion)
            }
            return false
        }
        return true
    }
    
    func noInternetCall<T>(error: NSError, completion: @escaping (Result<T, NetworkError>) -> Void) {
        Log("Network Stack: No internet! error: \(error)", module: .network)
        DispatchQueue.main.async {
            completion(.failure(.noInternet))
        }
    }
    
    func serverErrorCall<T>(error: NSError, completion: @escaping (Result<T, NetworkError>) -> Void) {
        Log("Network Stack: Server error! error: \(error)", module: .network)
        DispatchQueue.main.async {
            completion(.failure(.connection(error: .serverError)))
        }
    }
    
    func otherErrorCall<T>(error: NSError?, completion: @escaping (Result<T, NetworkError>) -> Void) {
        Log("Network Stack: Other error! error: \(String(describing: error))", module: .network)
        DispatchQueue.main.async {
            completion(.failure(.connection(error: .otherError)))
        }
    }
    
    func serverResponseError<T>(
        path: String?,
        status: Int,
        returnedError: ReturnedError?,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        // swiftlint:disable line_length
        Log("Network Stack: Server response error! Path: \(path ?? "<unknown>"), status: \(status), returnedError: \(String(describing: returnedError))", module: .network)
        // swiftlint:enable line_length
        DispatchQueue.main.async {
            completion(.failure(.connection(error: .serverHTTPError(status: status, error: returnedError))))
        }
    }
    
    func parseError<T>(completion: @escaping (Result<T, NetworkError>) -> Void) {
        DispatchQueue.main.async {
            completion(.failure(.connection(error: .parseError)))
        }
    }
}
