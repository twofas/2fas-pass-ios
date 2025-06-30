// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public protocol TimerInteracting: AnyObject {
    var timerTicked: Callback? { get set }
    var tickTime: Int { get }
    var isRunning: Bool { get }
    
    func setTickEverySecond(seconds: Int)
    func destroy()
    func pause()
    func start()
}

public final class TimerInteractor {
    private var timer: Timer?
    private var isDestroyed = false
    
    public var timerTicked: Callback?
    public private(set) var tickTime: Int = 1
    public private(set) var isRunning = false
        
    public init() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

extension TimerInteractor: TimerInteracting {
    public func setTickEverySecond(seconds: Int) {
        tickTime = seconds
    }
    
    public func destroy() {
        isDestroyed = true
        isRunning = false
        clearTimer()
    }
    
    public func pause() {
        isRunning = false
        clearTimer()
    }
    
    public func start() {
        isRunning = true
        startTimer()
    }
}

private extension TimerInteractor {
    @objc
    func applicationDidBecomeActive() {
        if isRunning {
            startTimer()
        }
    }
    
    @objc
    func applicationDidEnterBackground() {
        clearTimer()
    }
    
    func clearTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func startTimer() {
        guard timer == nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: Double(tickTime), repeats: true, block: { [weak self] timer in
            guard let self, !self.isDestroyed else {
                timer.invalidate()
                return
            }
            
            guard self.isRunning else { return }
            
            self.timerTicked?()
        })
    }
}
