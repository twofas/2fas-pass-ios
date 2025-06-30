// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Kronos

extension MainRepositoryImpl {
    var timeOffset: TimeInterval {
        if let cachedTimeOffset {
            return cachedTimeOffset
        }
        let offset = userDefaultsDataSource.timeOffset
        cachedTimeOffset = offset
        return offset
    }
    
    func setTimeOffset(_ offset: TimeInterval) {
        userDefaultsDataSource.setTimeOffset(offset)
        cachedTimeOffset = offset
        
        updateTimeOffsetListeners()
    }
    
    func checkTimeOffset(completion: @escaping (TimeInterval?) -> Void) {
        Clock.sync(samples: 1, completion: { _, timeInterval in
            guard let timeInterval else {
                Log("Can't get time interval while checking time offset", module: .mainRepository, severity: .warning)
                completion(nil)
                return
            }
            Log("Time offset fetched: \(timeInterval)", module: .mainRepository)
            completion(timeInterval)
        })
    }
    
    var currentDate: Date {
        Date() + timeOffset
    }
}
