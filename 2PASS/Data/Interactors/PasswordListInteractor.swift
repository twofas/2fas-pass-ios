// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol PasswordListInteracting: AnyObject {
    var currentSortType: SortType { get }
    func setSortType(_ sortType: SortType)
    
    func mostUsedUsernames() -> [String]
}

final class PasswordListInteractor {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension PasswordListInteractor: PasswordListInteracting {
    var currentSortType: SortType {
        mainRepository.sortType ?? .az
    }
    
    func setSortType(_ sortType: SortType) {
        Log("PasswordListInteractor: setting sort type to: \(sortType)", module: .interactor)
        mainRepository.setSortType(sortType)
    }
    
    func mostUsedUsernames() -> [String] {
        var aggregate: [String: Int] = [:]
        for name in mainRepository.listUsernames() {
            guard !name.isEmpty else { continue }
            var count: Int = aggregate[name] ?? 0
            count += 1
            aggregate[name] = count
        }
        return aggregate.sorted(by: { $0.value >= $1.value })
            .prefix(5)
            .map({ $0.key })
    }
}
