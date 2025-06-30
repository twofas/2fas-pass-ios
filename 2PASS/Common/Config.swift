// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum Config {
    public static let tosURL = URL(string: "https://2fas.com/terms-of-service/")!
    public static let suiteName = "group.twopass.twofas.com"

    public static let maxIdentifierLength: Int = 128
    public static let minMasterPasswordLength = 9
    public static let iconDimension = 42
    public static let defaultIconLabel = ""
    public static let maxLabelLength = 2
    public static let scaleImageSize = CGSize(width: 128, height: 128)
    public enum kdfSpec {
        public static let algorithm: KDFSpec.KDFType = .argon2id
        public static let hashLength: Int = 32
        public static let memoryMB: Int = 64
        public static let iterations: Int = 3
        public static let parallelism: Int = 4
    }
    public static let mainVaultName = "Main Vault"
    public static let wordsCount = 15
    public static let schemaVersion = 1
    public static let webDAVLockFileTime = 30
    public static let maxNotesLength = 2048
    public static let maxURICount = 9
    
    public static let cloudSchemaVersion = 1
    public static let indexSchemaVersion = 1
    public static let containerIdentifier = "iCloud.com.twopass.org.Vault"
    
    public static let maximumExternalImportFileSize = 1024 * 1024 * 20
    
    // AutoFill
    public static let autoFillExcludeProtectionLevels: Set<PasswordProtectionLevel> = [.topSecret]
    public static let allowsMatchRulesForSuggestions: Set<PasswordURI.Match> = [.domain]
    
    public static func iconURL(forDomain domain: String) -> URL? {
        URL(string: "https://icon.2fas.com/\(domain)/favicon.png")
    }
    
    public static func defaultIconLabel(forName name: String) -> String {
        name.twoLetters
    }
    
    public static let twoFASBaseURL = URL(string: "https://pass.2fas.com/")!
    public static let devTwoFASBaseURL = URL(string: "https://dev-pass.2fas.com/")!
    
    public enum Connect {
        public static let baseURL = URL(string: "wss://pass.2fas.com/proxy/mobile/")!
        public static let devBaseURL = URL(string: "wss://dev-pass.2fas.com/proxy/mobile/")!
        public static let schemeVersion = 1
        
        public static let sessionIdByteCount = 16
        public static let nonceByteCount = 12
        public static let passwordNonceByteCount = 12
        public static let hkdfSaltByteCount = 16
        
        public static let chunkSize = 2 * 1024 * 1024
        
        public static let notificationExpiryOffset: TimeInterval = 120
    }
    
    public enum Payment {
        public static let apiKey = "appl_LGhEtuwpiAFxecagLsZOLhrQecu"
        public static let subscriptionId = "unlimited" // entitlement_id
        
        public static let freeEntitlements = SubscriptionPlan.Entitlements(itemsLimit: 50, connectedBrowsersLimit: 1, multiDeviceSync: false)
        public static let premiumEntitlements = SubscriptionPlan.Entitlements(itemsLimit: nil, connectedBrowsersLimit: nil, multiDeviceSync: true)
    }
}
