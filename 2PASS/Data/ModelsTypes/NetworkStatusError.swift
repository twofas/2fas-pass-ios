// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension Int {
    var isNetworkError: Bool {
        networkError.contains(self)
    }
    
    var isServerError: Bool {
        serverError.contains(self)
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
            NSURLErrorBadURL,
            NSURLErrorUnsupportedURL,
            NSURLErrorBadServerResponse,
            NSURLErrorRedirectToNonExistentLocation,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorUserAuthenticationRequired,
            NSURLErrorZeroByteResource,
            NSURLErrorCannotDecodeRawData,
            NSURLErrorCannotDecodeContentData,
            NSURLErrorCannotParseResponse,
            NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorServerCertificateHasUnknownRoot,
            NSURLErrorServerCertificateNotYetValid,
            NSURLErrorClientCertificateRejected,
            NSURLErrorClientCertificateRequired,
            NSURLErrorCannotLoadFromNetwork
        ]
    }
}
