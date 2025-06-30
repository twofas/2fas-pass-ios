// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Combine
import UIKit

@Observable
public final class KeyboardObserver {
    var isKeyboardVisible: Bool = false
    var keyboardHeight = 0.0
    private var cancellableSet: Set<AnyCancellable> = []
    
    public init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { [weak self] notif in
                if let frame = (notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                    self?.keyboardHeight = frame.height
                }
                return true
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { [weak self] _ in
                self?.keyboardHeight = 0
                return false
            }
        
        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .assign(to: \.isKeyboardVisible, on: self)
            .store(in: &cancellableSet)
    }
}
