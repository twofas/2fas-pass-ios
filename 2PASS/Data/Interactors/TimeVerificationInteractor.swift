// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol TimeVerificationInteracting: AnyObject {
    func startVerification()
}

final class TimeVerificationInteractor {
    private let mainRepository: MainRepository
    
    private var isTimeValid = false
    private var isValidating = false
        
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension TimeVerificationInteractor: TimeVerificationInteracting {
    public func startVerification() {
        guard !isTimeValid && !isValidating else { return }
        isValidating = true
        Log("TimeVerification - Starting")
        Task {
            mainRepository.checkTimeOffset { [weak self] timeInterval in
                Task { @MainActor [weak self] in
                    self?.isValidating = false
                    guard let timeInterval else {
                        return
                    }
                    self?.isTimeValid = true
                    self?.mainRepository.setTimeOffset(timeInterval)
                }
            }
        }
    }
}
