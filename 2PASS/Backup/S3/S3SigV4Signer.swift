// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CryptoKit

struct S3SigV4Signer {
    static let emptyBodySHA256Hex = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    static func sha256Hex(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).hexEncodedString()
    }

    static func sign(
        request: inout URLRequest,
        bodySHA256Hex: String,
        now: Date,
        config: S3ServiceConfig
    ) {
        guard let url = request.url, let host = url.host() else { return }

        let amzDate = Self.amzDate(now)
        let dateStamp = String(amzDate.prefix(8))
        let service = "s3"

        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(bodySHA256Hex, forHTTPHeaderField: "x-amz-content-sha256")

        let method = request.httpMethod ?? "GET"
        let canonicalURI = Self.canonicalURI(from: url)
        let canonicalQuery = Self.canonicalQuery(from: url)
        let (canonicalHeaders, signedHeaders) = Self.canonicalHeaders(from: request)

        let canonicalRequest = [
            method,
            canonicalURI,
            canonicalQuery,
            canonicalHeaders,
            signedHeaders,
            bodySHA256Hex
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(config.region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            Self.sha256Hex(Data(canonicalRequest.utf8))
        ].joined(separator: "\n")

        let kDate = Self.hmac(key: Data("AWS4\(config.secretAccessKey)".utf8), message: dateStamp)
        let kRegion = Self.hmac(key: kDate, message: config.region)
        let kService = Self.hmac(key: kRegion, message: service)
        let kSigning = Self.hmac(key: kService, message: "aws4_request")
        let signature = Self.hmac(key: kSigning, message: stringToSign).hexEncodedString()

        let authorization = "AWS4-HMAC-SHA256 "
            + "Credential=\(config.accessKeyId)/\(credentialScope),"
            + "SignedHeaders=\(signedHeaders),"
            + "Signature=\(signature)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }
}

private extension S3SigV4Signer {
    static let amzDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func amzDate(_ date: Date) -> String {
        amzDateFormatter.string(from: date)
    }

    static func canonicalURI(from url: URL) -> String {
        let path = url.path(percentEncoded: true)
        return path.isEmpty ? "/" : path
    }

    static func canonicalQuery(from url: URL) -> String {
        guard
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            !items.isEmpty
        else {
            return ""
        }
        let encoded = items.map { item -> (String, String) in
            let key = item.name.addingPercentEncoding(withAllowedCharacters: .awsUnreserved) ?? item.name
            let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: .awsUnreserved) ?? ""
            return (key, value)
        }
        return encoded
            .sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
    }

    static func canonicalHeaders(from request: URLRequest) -> (canonical: String, signed: String) {
        let headers = request.allHTTPHeaderFields ?? [:]
        let filtered = headers.filter { key, _ in
            let lowered = key.lowercased()
            return lowered == "host" || lowered == "content-type" || lowered.hasPrefix("x-amz-")
        }
        let normalized = filtered
            .map { (key: $0.key.lowercased(), value: Self.collapseWhitespace($0.value)) }
            .sorted { $0.key < $1.key }
        let canonical = normalized.map { "\($0.key):\($0.value)\n" }.joined()
        let signed = normalized.map(\.key).joined(separator: ";")
        return (canonical, signed)
    }

    static func collapseWhitespace(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        var result = ""
        var previousWasSpace = false
        for character in trimmed {
            if character == " " {
                if !previousWasSpace { result.append(character) }
                previousWasSpace = true
            } else {
                result.append(character)
                previousWasSpace = false
            }
        }
        return result
    }

    static func hmac(key: Data, message: String) -> Data {
        let code = HMAC<SHA256>.authenticationCode(
            for: Data(message.utf8),
            using: SymmetricKey(data: key)
        )
        return Data(code)
    }
}

extension CharacterSet {
    /// AWS SigV4 mandates RFC 3986 unreserved (`A-Za-z0-9-_.~`) for path/key segments and
    /// certain headers. Must match what callers use to build the URL, or signatures fail.
    static let awsUnreserved: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        return set
    }()
}
