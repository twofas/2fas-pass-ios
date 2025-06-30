// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public extension Int {
    var isNetworkError: Bool {
        networkError.contains(self)
    }
    
    var isServerError: Bool {
        serverError.contains(self)
    }
    
    var isURLError: Bool {
        urlError.contains(self)
    }
    
    var isSSLError: Bool {
        sslError.contains(self)
    }
    
    var isUserAuthError: Bool {
        userAuthError.contains(self)
    }
    
    private var networkError: [Int] {
        [
            NSURLErrorUnknown,
            NSURLErrorCancelled,
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorDNSLookupFailed,
            NSURLErrorHTTPTooManyRedirects,
            NSURLErrorResourceUnavailable,
            NSURLErrorNotConnectedToInternet
        ]
    }
    
    private var serverError: [Int] {
        [
            NSURLErrorBadServerResponse,
            NSURLErrorRedirectToNonExistentLocation,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorZeroByteResource,
            NSURLErrorCannotDecodeRawData,
            NSURLErrorCannotDecodeContentData,
            NSURLErrorCannotParseResponse,
            NSURLErrorCannotLoadFromNetwork
        ]
    }
    
    private var urlError: [Int] {
        [
            NSURLErrorBadURL,
            NSURLErrorUnsupportedURL
        ]
    }
    
    private var sslError: [Int] {
        [
            NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorServerCertificateHasUnknownRoot,
            NSURLErrorServerCertificateNotYetValid,
            NSURLErrorClientCertificateRejected,
            NSURLErrorClientCertificateRequired,
        ]
    }
    
    private var userAuthError: [Int] {
        [
            NSURLErrorUserCancelledAuthentication,
            NSURLErrorUserAuthenticationRequired,
        ]
    }
}
