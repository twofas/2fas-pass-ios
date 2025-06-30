// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import XCTest
@testable import Data

final class URIInteractorTests: XCTestCase {
    private var interactor: URIInteractor!
    
    override func setUp() {
        interactor = URIInteractor()
    }

    override func tearDown() {
        interactor = nil
    }
    
    func testEmpty() {
        // GIVEN
        let urlString = ""
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertNil(result)
    }

    func testIDN1() {
        // GIVEN
        let urlString = "http://räksmörgås.josefsson.org"
        let expectedString = "http://xn--rksmrgs-5wao1o.josefsson.org"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testIDN2() {
        // GIVEN
        let urlString = "http://納豆.w3.mag.keio.ac.jp/"
        let expectedString = "http://xn--99zt52a.w3.mag.keio.ac.jp"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testIDN3() {
        // GIVEN
        let urlString = "https://häuser.com/"
        let expectedString = "https://xn--huser-gra.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testIDN4() {
        // GIVEN
        let urlString = "https://grüsse.com/"
        let expectedString = "https://xn--grsse-lva.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testIDN5() {
        // GIVEN
        let urlString = "https://足球.com/"
        let expectedString = "https://xn--5eyx16c.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testIDN6() {
        // GIVEN
        let urlString = "https://футбольный.com/"
        let expectedString = "https://xn--90aqfidwgh3ei.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testPrependProtocol1() {
        // GIVEN
        let urlString = "www.domain.com/?path=here"
        let expectedString = "https://domain.com/?path=here"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testPrependProtocol2() {
        // GIVEN
        let urlString = "http://www.domain.com"
        let expectedString = "http://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testPrependProtocol3() {
        // GIVEN
        let urlString = "https://www.domain.com"
        let expectedString = "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testPrependProtocol4() {
        // GIVEN
        let urlString = "http://domain.com"
        let expectedString = "http://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testPrependProtocol5() {
        // GIVEN
        let urlString = "domain.com"
        let expectedString = "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testPrependProtocol6() {
        // GIVEN
        let urlString = "domain"
        let expectedString = "domain"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testPrependProtocol7() {
        // GIVEN
        let urlString = "domain.pepepe"
        let expectedString = "domain.pepepe"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testPrependProtocol8() {
        // GIVEN
        let urlString = "domain.social"
        let expectedString = "https://domain.social"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testCleanURLParameters1() {
        // GIVEN
        let urlString = "https://www.domain.com/about-us/?utm_source=google&utm_medium=profile&utm_campaign=gmb"
        let expectedString = "https://domain.com/about-us"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testCleanURLParameters2() {
        // GIVEN
        let urlString = "https://www.domain.com/about-us/?moj_param=4&utm_source=google&utm_medium=profile&utm_campaign=gmb&test=true"
        let expectedString = "https://domain.com/about-us/?moj_param=4&test=true"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testRemoveTrailingChars1() {
        // GIVEN
        let urlString = "https://www.domain.com/"
        let expectedString = "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testRemoveTrailingChars2() {
        // GIVEN
        let urlString = "https://www.domain.com/about-us/"
        let expectedString = "https://domain.com/about-us"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testRemoveTrailingChars3() {
        // GIVEN
        let urlString = "https://www.domain.com/?"
        let expectedString = "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testRemoveTrailingChars4() {
        // GIVEN
        let urlString = "https://www.domain.com/#"
        let expectedString = "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testRemoveTrailingChars5() {
        // GIVEN
        let urlString = "https://www.domain.com/?#"
        let expectedString =  "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testRemoveTrailingChars6() {
        // GIVEN
        let urlString = "https://www.domain.com/#?"
        let expectedString = "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testRemoveTrailingChars7() {
        // GIVEN
        let urlString = "https://www.domain.com/?test"
        let expectedString = "https://domain.com/?test"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testRemoveTrailingChars8() {
        // GIVEN
        let urlString = "https://www.domain.com/#test"
        let expectedString = "https://domain.com/#test"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testLowerCaseURLWithoutPort1() {
        // GIVEN
        let urlString = "https://www.DOMAIN.com"
        let expectedString = "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testLowerCaseURLWithoutPort2() {
        // GIVEN
        let urlString = "https://www.domain.com"
        let expectedString = "https://domain.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testLowerCaseURLWithoutPort3() {
        // GIVEN
        let urlString = "https://WWW.google.com:443/?abc=ABC"
        let expectedString = "https://google.com/?abc=ABC"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testLowerCaseURLWithoutPort4() {
        // GIVEN
        let urlString = "httpS://google.com/?abc=ABC"
        let expectedString = "https://google.com/?abc=ABC"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testLowerCaseURLWithoutPort5() {
        // GIVEN
        let urlString = "httpS://google.com/?abc=ABC "
        let expectedString = "https://google.com/?abc=ABC"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testURLEncode1() {
        // GIVEN
        let urlString = "http://example.com/foo%2b"
        let expectedString = "http://example.com/foo+"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testURLEncode2() {
        // GIVEN
        let urlString = "http://example.com/%7Efoo"
        let expectedString = "http://example.com/~foo"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testComplexNormalization1() {
        // GIVEN
        let urlString = "   http://räksmörgås.josefsson.org   "
        let expectedString = "http://xn--rksmrgs-5wao1o.josefsson.org"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testComplexNormalization2() {
        // GIVEN
        let urlString = " http://häuseR.com/?"
        let expectedString = "http://xn--huser-gra.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testComplexNormalization3() {
        // GIVEN
        let urlString = "https://футбольный.com:443/?abc=ABC "
        let expectedString = "https://xn--90aqfidwgh3ei.com/?abc=ABC"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testComplexNormalization4() {
        // GIVEN
        let urlString = "httpS://футбольный.com:443/?abc=ABC"
        let expectedString = "https://xn--90aqfidwgh3ei.com/?abc=ABC"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testComplexNormalization5() {
        // GIVEN
        let urlString = "https://häuseR.com/?# "
        let expectedString = "https://xn--huser-gra.com"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
    
    func testComplexNormalization6() {
        // GIVEN
        let urlString = " 2fas.com/%7Efoo/?#"
        let expectedString = "https://2fas.com/~foo"
        
        // WHEN
        let result = interactor.normalize(urlString)
        
        // THEN
        XCTAssertEqual(result, expectedString)
    }
}
