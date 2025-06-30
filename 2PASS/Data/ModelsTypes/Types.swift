// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

typealias CloudStateListenerID = String
typealias CloudStateListener = (CloudState) -> Void

public typealias MasterPassword = String
public typealias MasterKey = Data
public typealias MasterKeyEncrypted = Data
public typealias Seed = Data
public typealias Salt = Data
public typealias Entropy = Data
public typealias AppKey = Data
public typealias BiometryKey = Data
public typealias TrustedKey = Data
public typealias SecureKey = Data
public typealias ExternalKey = Data
