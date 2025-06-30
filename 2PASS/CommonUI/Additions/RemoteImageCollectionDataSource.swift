// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol RemoteImageCollectionFetcher: AnyObject {
    func cachedImage(from url: URL) -> Data?
    func fetchImage(from url: URL) async throws -> Data
}

public final class RemoteImageCollectionDataSource<Item> where Item: Identifiable {
    
    private struct ItemURL: Hashable {
        var item: Item
        var url: URL
        
        static func ==(lhs: ItemURL, rhs: ItemURL) -> Bool {
            lhs.item.id == rhs.item.id && lhs.url == rhs.url
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(item.id)
            hasher.combine(url)
        }
    }
    
    let fetcher: RemoteImageCollectionFetcher

    public init(fetcher: RemoteImageCollectionFetcher) {
        self.fetcher = fetcher
    }
    
    @MainActor
    public var onImageFetchResult: (Item, URL, Result<Data, Error>) -> Void = { _, _, _ in }
    
    @MainActor
    private var tasks: [ItemURL: Task<Void, Never>] = [:]
    
    @MainActor
    public func cachedImage(from url: URL) -> Data? {
        fetcher.cachedImage(from: url)
    }
    
    @MainActor
    public func fetchImage(from url: URL, for item: Item) {
        let task = Task { [fetcher, weak self] in
            do {
                let imageData = try await fetcher.fetchImage(from: url)
                self?.onImageFetchResult(item, url, .success(imageData))
            } catch {
                self?.onImageFetchResult(item, url, .failure(error))
            }
        }
        
        tasks[ItemURL(item: item, url: url)] = task
    }

    @MainActor
    public func cancelFetches(for item: Item) {
        for (element, task) in tasks where element.item.id == item.id {
            task.cancel()
        }
    }
}
