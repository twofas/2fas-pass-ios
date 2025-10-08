// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum Config {
    
    public static let tosURL = URL(string: "https://2fas.com/pass/eula")!
    public static let privacyPolicyURL = URL(string: "https://2fas.com/pass/privacy-policy")!
    public static let openSourceLicencesURL = URL(string: "https://2fas.com/pass/open-source-licenses")!
    public static let appStoreURL = URL(string: "https://apps.apple.com/us/app/2fas-pass-password-manager/id6504464955")!
    
    #if PROD
    public static let suiteName = "group.twopass.twofas.com"
    #else
    public static let suiteName = "group.dev.twopass.twofas.com"
    #endif
    
    #if PROD
    public static let keychainGroup = "ZY8UR5ADFW.group.com.twofas.org.TwoPASS"
    public static let keychainSharedGroup = "ZY8UR5ADFW.group.com.twofas.org.TwoPASS.Shared"
    #else
    public static let keychainGroup = "ZY8UR5ADFW.group.com.twofas.org.TwoPASS.dev"
    public static let keychainSharedGroup = "ZY8UR5ADFW.group.com.twofas.org.TwoPASS.dev.Shared"
    #endif

    public static let maxIdentifierLength: Int = 128
    public static let minMasterPasswordLength = 9
    public static let iconDimension = 42
    public static let defaultIconLabel = ""
    public static let maxLabelLength = 2
    public static let scaleImageSize = CGSize(width: 128, height: 128)
    public static let maxTagNameLength: Int = 64
    
    public enum kdfSpec {
        public static let algorithm: KDFSpec.KDFType = .argon2id
        public static let hashLength: Int = 32
        public static let memoryMB: Int = 64
        public static let iterations: Int = 3
        public static let parallelism: Int = 4
    }
    public static let mainVaultName = "Main Vault"
    public static let wordsCount = 15
    public static let schemaVersion = 2
    public static let webDAVLockFileTime = 30
    public static let maxNotesLength = 2048
    public static let maxURICount = 9
    
    public static let connectSchemaVersion = 1
    public static let cloudSchemaVersion = 2
    public static let indexSchemaVersion = 1
    #if PROD
    public static let containerIdentifier = "iCloud.com.twopass.org.Vault"
    #else
    public static let containerIdentifier = "iCloud.com.twopass.org.dev.Vault"
    #endif
    
    public static let maximumExternalImportFileSize = 1024 * 1024 * 20
    
    // AutoFill
    public static let autoFillExcludeProtectionLevels: Set<ItemProtectionLevel> = [.topSecret]
    public static let allowsMatchRulesForSuggestions: Set<PasswordURI.Match> = [.domain]
    
    public static func iconURL(forDomain domain: String) -> URL? {
        URL(string: "https://icon.2fas.com/\(domain)/favicon.png")
    }
    
    public static func defaultIconLabel(forName name: String) -> String {
        name.twoLetters
    }
    
    #if PROD
    public static let twoFASBaseURL = URL(string: "https://pass.2fas.com/")!
    #else
    public static let twoFASBaseURL = URL(string: "https://dev-pass.2fas.com/")!
    #endif
        
    public enum Connect {
        #if PROD
        public static let baseURL = URL(string: "wss://pass.2fas.com/proxy/mobile/")!
        #else
        public static let baseURL = URL(string: "wss://dev-pass.2fas.com/proxy/mobile/")!
        #endif
        
        public static let schemaVersion = 1
        
        public static let sessionIdByteCount = 16
        public static let nonceByteCount = 12
        public static let passwordNonceByteCount = 12
        public static let hkdfSaltByteCount = 16
        
        public static let chunkSize = 2 * 1024 * 1024
        
        public static let notificationExpiryOffset: TimeInterval = 120
    }
    
    public enum Payment {
        #if PROD
        public static let apiKey = "appl_LGhEtuwpiAFxecagLsZOLhrQecu"
        public static let subscriptionId = "unlimited" // entitlement_id
        #else
        public static let apiKey = "appl_yjcWohjWjdFeWjdyYEUuCcTPagb"
        public static let subscriptionId = "unlimited" // entitlement_id
        #endif
        
        public static let freeEntitlements = SubscriptionPlan.Entitlements(itemsLimit: 200, connectedBrowsersLimit: 1, multiDeviceSync: false)
        public static let premiumEntitlements = SubscriptionPlan.Entitlements(itemsLimit: nil, connectedBrowsersLimit: nil, multiDeviceSync: true)
    }
    
    public static let twofasAuthCheckLink = URL(string: "twofasauth://")!
    public static let twofasAuthOpenLink = URL(string: "twofasauth://open")!
    public static let twofasAuthAppStoreLink = URL(string: "itms-apps://itunes.apple.com/app/id1217793794")!
}
