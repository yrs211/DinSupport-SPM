//
//  DinGCDTimer.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

public enum DinTimerInterval {
  case nanoseconds(_: Int)
  case microseconds(_: Int)
  case milliseconds(_: Int)
  case seconds(_: Double)
  case hours(_: Int)
  case days(_: Int)

  internal var value: DispatchTimeInterval {
    switch self {
    case .nanoseconds(let value):        return .nanoseconds(value)
    case .microseconds(let value):        return .microseconds(value)
    case .milliseconds(let value):        return .milliseconds(value)
    case .seconds(let value):            return .milliseconds(Int( Double(value) * Double(1000)))
    case .hours(let value):            return .seconds(value * 3600)
    case .days(let value):            return .seconds(value * 86400)
       }
   }
}

public class DinGCDTimer: NSObject {
    /// 时间间隔
    private var timerInterval: DinTimerInterval

    /// 是否重复
    private var isRepeat: Bool = false

    /// 允许的误差
    private var torelance: DispatchTimeInterval

    /// 执行方法的线程
    private var executeQueue: DispatchQueue

    /// 执行方法
    private var executeBlock: (() -> Void)?

    /// 计时器
    public var timer: DispatchSourceTimer?

    /// 生成计时器
    /// - Parameters:
    ///   - timerInterval: 时间间隔
    ///   - isRepeat: 是否重复
    ///   - torelance: 容忍时间（准确率）
    ///   - executeBlock: 处理方法
    ///   - queue: 处理方法所在的线程
    public init(timerInterval: DinTimerInterval,
                isRepeat: Bool,
                torelance: DispatchTimeInterval = .microseconds(100),
                executeBlock: @escaping () -> Void,
                queue: DispatchQueue = DispatchQueue.global()) {
        self.timerInterval = timerInterval
        self.isRepeat = isRepeat
        self.torelance = torelance
        self.executeQueue = queue
        super.init()
        self.executeBlock = executeBlock
        self.timer = configureTimer()
    }

    private func configureTimer() -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: executeQueue)
        let repatInterval = timerInterval.value
        let deadline: DispatchTime = (DispatchTime.now() + repatInterval)
        if isRepeat {
          timer.schedule(deadline: deadline, repeating: repatInterval, leeway: torelance)
        } else {
          timer.schedule(deadline: deadline, leeway: torelance)
        }

        timer.setEventHandler { [weak self] in
            if let unwrapped = self, let nowTimer = unwrapped.timer, timer === (nowTimer as AnyObject)  {
                unwrapped.executeBlock?()
          }
        }
        state = .resumed
        timer.resume()
        return timer
    }

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer?.setEventHandler {}
        timer?.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        executeBlock = nil
    }

    private func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer?.resume()
    }

    public func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer?.suspend()
    }
}
