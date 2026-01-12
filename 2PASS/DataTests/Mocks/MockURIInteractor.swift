// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
@testable import Data

final class MockURIInteractor: URIInteracting {

    // MARK: - Call Tracking

    private(set) var methodCalls: [String] = []

    private func recordCall(_ name: String = #function) {
        methodCalls.append(name)
    }

    func resetCalls() {
        methodCalls.removeAll()
    }

    func wasCalled(_ method: String) -> Bool {
        methodCalls.contains(method)
    }

    func callCount(_ method: String) -> Int {
        methodCalls.filter { $0 == method }.count
    }

    // MARK: - Stubbed Properties

    private var stubbedIsSecureURL: (URL) -> Bool = { _ in true }
    private var stubbedNormalize: (String) -> String? = { $0 }
    private var stubbedNormalizeURL: (String) -> URL? = { URL(string: $0) }
    private var stubbedNormalizeURLWithOptions: (String, URINormalizeOptions) -> URL? = { str, _ in URL(string: str) }
    private var stubbedExtractDomain: (String) -> String? = { $0 }
    private var stubbedIsMatch: (String, String, PasswordURI.Match) -> Bool = { _, _, _ in true }

    // MARK: - Stub Configuration

    @discardableResult
    func withIsSecureURL(_ handler: @escaping (URL) -> Bool) -> Self {
        stubbedIsSecureURL = handler
        return self
    }

    @discardableResult
    func withNormalize(_ handler: @escaping (String) -> String?) -> Self {
        stubbedNormalize = handler
        return self
    }

    @discardableResult
    func withNormalizeURL(_ handler: @escaping (String) -> URL?) -> Self {
        stubbedNormalizeURL = handler
        return self
    }

    @discardableResult
    func withNormalizeURLWithOptions(_ handler: @escaping (String, URINormalizeOptions) -> URL?) -> Self {
        stubbedNormalizeURLWithOptions = handler
        return self
    }

    @discardableResult
    func withExtractDomain(_ handler: @escaping (String) -> String?) -> Self {
        stubbedExtractDomain = handler
        return self
    }

    @discardableResult
    func withIsMatch(_ handler: @escaping (String, String, PasswordURI.Match) -> Bool) -> Self {
        stubbedIsMatch = handler
        return self
    }

    // MARK: - URIInteracting

    func isSecureURL(_ url: URL) -> Bool {
        recordCall()
        return stubbedIsSecureURL(url)
    }

    func normalize(_ str: String) -> String? {
        recordCall()
        return stubbedNormalize(str)
    }

    func normalizeURL(_ str: String) -> URL? {
        recordCall()
        return stubbedNormalizeURL(str)
    }

    func normalizeURL(_ str: String, options: URINormalizeOptions) -> URL? {
        recordCall()
        return stubbedNormalizeURLWithOptions(str, options)
    }

    func extractDomain(from str: String) -> String? {
        recordCall()
        return stubbedExtractDomain(str)
    }

    func isMatch(_ str: String, to uri: String, rule: PasswordURI.Match) -> Bool {
        recordCall()
        return stubbedIsMatch(str, uri, rule)
    }
}
