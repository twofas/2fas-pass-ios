// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public protocol CurrentDateInteracting: AnyObject {
    var currentDate: Date { get }
}

final class CurrentDateInteractor: CurrentDateInteracting {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    var currentDate: Date {
        mainRepository.currentDate
    }
}
