// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum FileIconError: Error {
    case networkError(error: NetworkError)
    case imageError
}

public protocol FileIconInteracting: AnyObject {
    func fetchImage(from url: URL, completion: @escaping (Result<Data, FileIconError>) -> Void)
    
    func cachedImage(from url: URL) -> Data?
    func fetchImage(from url: URL) async throws -> Data
}

final class FileIconInteractor {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension FileIconInteractor: FileIconInteracting {
    func fetchImage(from url: URL, completion: @escaping (Result<Data, FileIconError>) -> Void) {
        mainRepository.fetchFile(from: url) { result in
            switch result {
            case .success(let data):
                Log("FileIconInteractor: image fetched", module: .interactor)
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let img = self.mainRepository.resizeImage(from: data, to: Config.scaleImageSize) else {
                        Log("FileIconInteractor: Can't resize fetched image", module: .interactor, severity: .error)
                        DispatchQueue.main.async {
                            completion(.failure(.imageError))
                        }
                        return
                    }
                    Log("FileIconInteractor: image resized", module: .interactor)
                    DispatchQueue.main.async {
                        completion(.success(img))
                    }
                }
            case .failure(let error):
                Log("FileIconInteractor: error while fetching image: \(error)", module: .interactor)
                completion(.failure(.networkError(error: error)))
            }
        }
    }
    
    func cachedImage(from url: URL) -> Data? {
        mainRepository.cachedImage(from: url)
    }
    
    func fetchImage(from url: URL) async throws -> Data {
        do {
            let data = try await mainRepository.fetchIconImage(from: url)
            Log("FileIconInteractor: image fetched \(url)", module: .interactor)
            return data
            
        } catch {
            switch error {
            case URLError.cancelled: break
            default:
                Log("FileIconInteractor: error while fetching image: \(url) \(error)", module: .interactor)
            }
            
            throw error
        }
    }
}
