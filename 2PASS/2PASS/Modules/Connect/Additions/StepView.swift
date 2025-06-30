// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let strikeThrougCompletedAnimationDuration = 0.3
    static let accessoryCompletedAnimationDuration = 0.4
    static let accessoryCompletedAnimationDelay = 0.2
    static let completedAnimationDuration = 0.3
    static let completedAnimationDelay = 0.6
    static let backgroundCornerRadius = 16.0
    static let backgroundCompletedOpacity = 16.0
}

struct StepView<Accesssory>: View where Accesssory: View {
    
    let title: Text
    let subtitle: Text
    let accessory: Accesssory
    
    private var completed: Bool
    
    init(title: Text, subtitle: Text, @ViewBuilder accessory: () -> Accesssory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
        self.completed = false
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                title
                    .font(.calloutEmphasized)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .frame(height: 1)
                            .frame(maxWidth: completed ? .infinity : 0)
                            .animation(.linear(duration: Constants.strikeThrougCompletedAnimationDuration), value: completed)
                    }
                    .foregroundStyle(completed ? .neutral300 : .neutral950)
                
                subtitle
                    .foregroundStyle(completed ? .neutral300 : .neutral500)
                    .font(.footnote)
            }
            
            Spacer(minLength: 0)
            
            accessory
                .animation(.easeInOut(duration: Constants.accessoryCompletedAnimationDuration).delay(Constants.accessoryCompletedAnimationDelay), value: completed)
        }
        .padding(Spacing.l)
        .background {
            RoundedRectangle(cornerRadius: Constants.backgroundCornerRadius)
                .foregroundStyle(.neutral50)
                .opacity(completed ? Constants.backgroundCompletedOpacity : 1)
        }
        .animation(.easeInOut(duration: Constants.completedAnimationDuration).delay(Constants.completedAnimationDelay), value: completed)
    }
    
    func completed(_ completed: Bool) -> Self {
        var instance = self
        instance.completed = completed
        return instance
    }
}

extension StepView where Accesssory == EmptyView {
    
    init(title: Text, subtitle: Text) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() })
    }
}

#Preview {
    @State @Previewable var completed: Bool = false
    
    VStack {
        StepView(
            title: Text("Camera Access"),
            subtitle: Text("Subtitle"),
            accessory: {
                if completed {
                    ConnectPermissionsStepAccessoryView(status: .failed)
                } else {
                    ConnectPermissionsStepAccessoryView(status: nil)
                }
            }
        )
        .completed(completed)
        .padding(.horizontal, 16)
        
        Button("Change") {
            completed.toggle()
        }
    }
}
