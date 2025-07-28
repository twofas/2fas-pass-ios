// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol SystemInteracting: AnyObject {
    var appVersion: String { get }
    var buildVersion: String { get }
    
    func copyToClipboard(_ str: String)
    
    var syncHasError: Bool { get }
    func setSyncHasError(_ value: Bool)
    
    func positiveFeedback()
    func negativeFeedback()
    func warningFeedback()
    
    var is2FASAuthInstalled: Bool { get }
}

final class SystemInteractor {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension SystemInteractor: SystemInteracting {
    var appVersion: String {
        mainRepository.currentAppVersion
    }
    
    var buildVersion: String {
        mainRepository.currentBuildVersion
    }
    
    func copyToClipboard(_ str: String) {
        mainRepository.copyToClipboard(str)
    }
    
    var syncHasError: Bool {
        mainRepository.syncHasError
    }
    
    func setSyncHasError(_ value: Bool) {
        mainRepository.setSyncHasError(value)
    }
    
    func positiveFeedback() {
        mainRepository.positiveFeedback()
    }
    
    func negativeFeedback() {
        mainRepository.negativeFeedback()
    }
    
    func warningFeedback() {
        mainRepository.warningFeedback()
    }
    
    var is2FASAuthInstalled: Bool {
        mainRepository.is2FASAuthInstalled
    }
}
