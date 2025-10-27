// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public enum Keys {
    
    public enum Connect {
        public static let session = "SessionKey"
        public static let data = "Data"
        
        // V1
        public static let passwordTier3 = "PassT3"
        public static let passwordTier2 = "PassT2"
        public static let newPassword = "PassNew"
        
        // V2
        public static let itemTier3 = "ItemT3"
        public static let itemTier2 = "ItemT2"
        public static let newItem = "ItemNew"
    }
}
