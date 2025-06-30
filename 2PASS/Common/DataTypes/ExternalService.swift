// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public enum ExternalService: CaseIterable, Equatable {
    case onePassword
    case applePasswordsDesktop
    case applePasswordsMobile
    case bitWarden
    case chrome
    case dashlaneMobile
    case dashlaneDesktop
    case lastPass
    case protonPass
}
