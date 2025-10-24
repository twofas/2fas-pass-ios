//
//  ConnectSchemaVersion.swift
//  2PASS
//
//  Created by Maciej Szewczyk on 24/10/2025.
//  Copyright © 2025 Two Factor Authentication Service, Inc. All rights reserved.
//

public enum ConnectSchemaVersion: Int, Comparable, Codable {
    case v1 = 1
    case v2
    
    public static func < (lhs: ConnectSchemaVersion, rhs: ConnectSchemaVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
