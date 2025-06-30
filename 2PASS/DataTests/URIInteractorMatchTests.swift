// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
@testable import Data

@Suite("URI Matching Rules") struct URIInteractorMatchTests {
    
    struct URITestItem: Sendable {
        let uri: String
        let shouldMatch: Bool
    }
    
    @Suite("Domain Rule") struct DomainMatchTests {
        
        @Test("All bases", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: true),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: true),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: true),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: true),
            URITestItem(uri: "https://domain.com/", shouldMatch: true),
            URITestItem(uri: "https://sd.domain.com/", shouldMatch: true),
            URITestItem(uri: "https://domain.net/", shouldMatch: false),
            URITestItem(uri: "https://domain.com:1234/", shouldMatch: true),
        ], [
            "https://www.domain.com/en/my.aspx?error=999",
            "https://www.domain.com/en/",
            "https://www.domain.com",
            "http://www.domain.com"
        ])
        func match(item: URITestItem, base: String) {
            #expect(URIInteractor().isMatch(item.uri, to: base, rule: .domain) == item.shouldMatch)
        }
    }
    
    @Suite("Host Rule") struct HostMatchTests {
        
        @Test("Base complex URI", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://www.sd.domain.com/en/my.aspx?error=999", shouldMatch: true),
            URITestItem(uri: "https://sd.domain.com/en/my.aspx?error=999", shouldMatch: true),
            URITestItem(uri: "https://sd.domain.com:1234/", shouldMatch: false),
            URITestItem(uri: "http://www.sd.domain.com/en/", shouldMatch: true),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.com/", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/", shouldMatch: true),
            URITestItem(uri: "https://domain.net/", shouldMatch: false),
            URITestItem(uri: "https://domain.com:1234/", shouldMatch: false),
        ])
        func matchToComplexURI(item: URITestItem) {
            #expect(URIInteractor().isMatch(item.uri, to: "https://www.sd.domain.com/en/my.aspx?error=999", rule: .host) == item.shouldMatch)
        }
 
        @Test("Base URI with port", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://www.sd.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com:1234/", shouldMatch: true),
            URITestItem(uri: "http://www.sd.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.com/", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.net/", shouldMatch: false),
            URITestItem(uri: "https://domain.com:1234/", shouldMatch: false),
        ], [
            "https://www.sd.domain.com:1234/en/",
            "http://www.sd.domain.com:1234"
        ])
        func matchToURIWithPort(item: URITestItem, base: String) {
            #expect(URIInteractor().isMatch(item.uri, to: base, rule: .host) == item.shouldMatch)
        }
    }
    
    @Suite("Prefix Rule") struct PrefixMatchTests {
        
        @Test("Base URI with WWW", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://www.sd.domain.com/en/my.aspx?error=999", shouldMatch: true),
            URITestItem(uri: "http://www.sd.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/en/my.aspx?error=999", shouldMatch: true),
            URITestItem(uri: "https://sd.domain.com:1234/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "http://www.sd.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: false)
        ])
        func match(item: URITestItem) {
            #expect(URIInteractor().isMatch(item.uri, to: "https://www.sd.domain.com/en/my", rule: .startsWith) == item.shouldMatch)
        }
        
        @Test("[Match] Base URI with WWW and port", arguments: [
            URITestItem(uri: "https://sd.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://www.sd.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com:1234/en/page/?param=1", shouldMatch: true),
            URITestItem(uri: "https://www.sd.domain.com:1234/en/page/?param=1", shouldMatch: true),
            URITestItem(uri: "http://www.sd.domain.com:1234/en/page/?param=1", shouldMatch: false)
        ])
        func matchURIWithPort(item: URITestItem) {
            #expect(URIInteractor().isMatch(item.uri, to: "https://www.sd.domain.com:1234/", rule: .startsWith) == item.shouldMatch)
        }
        
        @Test("[Not match] Base URI with WWW and port", arguments: [
            "https://sd.domain.com/en/my.aspx?error=999",
            "https://www.sd.domain.com/en/my.aspx?error=999",
            "http://www.sd.domain.com:1234/en/page/?param=1"
        ])
        func notMatchURIWithPort(uri: String) {
            #expect(URIInteractor().isMatch(uri, to: "https://www.sd.domain.com:1234/", rule: .startsWith) == false)
        }
    }
    
    @Suite("Exact Rule") struct ExactMatchTests {
        
        @Test("Base complex URI", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: true),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.com/", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.net/", shouldMatch: false),
            URITestItem(uri: "https://domain.com:1234/", shouldMatch: false)
        ])
        func matchToComplexURI(_ item: URITestItem) async throws {
            #expect(URIInteractor().isMatch(item.uri, to: "https://www.domain.com/en/my.aspx?error=999", rule: .exact) == item.shouldMatch)
        }
        
        @Test("Base URI with path", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: true),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.com/", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.net/", shouldMatch: false),
            URITestItem(uri: "https://domain.com:1234/", shouldMatch: false)
        ])
        func matchToURIWithPath(_ item: URITestItem) async throws {
            #expect(URIInteractor().isMatch(item.uri, to: "https://www.domain.com/en/", rule: .exact) == item.shouldMatch)
        }
        
        @Test("Base simple URI", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: true),
            URITestItem(uri: "https://domain.com/", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.net/", shouldMatch: false),
            URITestItem(uri: "https://domain.com:1234/", shouldMatch: false)
        ])
        func matchToSimpleURI(_ item: URITestItem) async throws {
            #expect(URIInteractor().isMatch(item.uri, to: "https://www.domain.com", rule: .exact) == item.shouldMatch)
        }
        
        @Test("Base simple URI without SSL", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.com/", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.net/", shouldMatch: false),
            URITestItem(uri: "https://domain.com:1234/", shouldMatch: false)
        ])
        func matchToSimpleURIWithoutSSL(_ item: URITestItem) async throws {
            #expect(URIInteractor().isMatch(item.uri, to: "http://www.domain.com", rule: .exact) == item.shouldMatch)
        }
        
        @Test("Base simple URI with port without SSL", arguments: [
            URITestItem(uri: "https://www.domain.com/en/my.aspx?error=999", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "http://www.domain.com/en/", shouldMatch: false),
            URITestItem(uri: "https://www.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.com/", shouldMatch: false),
            URITestItem(uri: "https://sd.domain.com/", shouldMatch: false),
            URITestItem(uri: "https://domain.net/", shouldMatch: false),
            URITestItem(uri: "https://domain.com:1234/", shouldMatch: false),
            URITestItem(uri: "http://www.domain.com:1234/", shouldMatch: true),
            URITestItem(uri: "http://domain.com:1234/", shouldMatch: false)
        ])
        func matchToSimpleURIWithPortWithoutSSL(_ item: URITestItem) async throws {
            #expect(URIInteractor().isMatch(item.uri, to: "http://www.domain.com:1234/", rule: .exact) == item.shouldMatch)
        }
    }
}
