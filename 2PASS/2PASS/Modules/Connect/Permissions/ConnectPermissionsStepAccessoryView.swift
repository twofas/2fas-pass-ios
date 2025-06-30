// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ConnectPermissionsStepAccessoryView: View {
    
    let status: ConnectPermissionsStepStatus?
    
    var body: some View {
        Group {
            switch status {
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
            case .failed:
                Image(systemName: "xmark.circle.fill")
            default:
                Image(systemName: "checkmark.circle.fill")
            }
        }
        .foregroundStyle(color)
    }
    
    private var color: Color {
        switch status {
        case nil:
            Color(UIColor(hexString: "#C3C3C3")!)
        case .failed:
            .danger500
        case .success:
            .brand500
        case .warning:
            .warning600
        }
    }
}

#Preview {
    VStack {
        ConnectPermissionsStepAccessoryView(status: nil)
        ConnectPermissionsStepAccessoryView(status: .success)
        ConnectPermissionsStepAccessoryView(status: .warning)
        ConnectPermissionsStepAccessoryView(status: .failed)
    }
}
