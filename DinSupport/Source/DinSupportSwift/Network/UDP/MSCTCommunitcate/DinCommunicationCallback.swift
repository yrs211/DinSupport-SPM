//
//  DinCommunicationCallback.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

enum DinCommunicationCallbackState {
    case success
    case fail
    case timout
}

public class DinCommunicationCallback: NSObject {
    /// 成功回调
    public typealias SuccessBlock = (_ result: DinMSCTResult) -> Void
    /// 失败回调
    public typealias FailureBlock = (_ errMsg: String) -> Void
    /// 超时回调
    public typealias TimeoutBlock = (_ messageID: String) -> Void

    // CallBacks
    public var successBlock: SuccessBlock?
    public var failureBlock: FailureBlock?
    public var timeoutBlock: TimeoutBlock?

    public init(successBlock: SuccessBlock?, failureBlock: FailureBlock?, timeoutBlock: TimeoutBlock?) {
        self.successBlock = successBlock
        self.failureBlock = failureBlock
        self.timeoutBlock = timeoutBlock
        super.init()
    }

    func result(_ state: DinCommunicationCallbackState, info: Any) {
        switch state {
        case .success:
            if let success = successBlock, let result = info as? DinMSCTResult {
                /// 收到的信息都在通道的线程里面，需要在主线程提交给上层处理
                DispatchQueue.main.async {
                    success(result)
                }
            }
        case .fail:
            if let fail = failureBlock, let errMsg = info as? String {
                /// 收到的信息都在通道的线程里面，需要在主线程提交给上层处理
                DispatchQueue.main.async {
                    fail(errMsg)
                }
            }
        default:
            if let timeout = timeoutBlock, let messageID = info as? String {
                /// 收到的信息都在通道的线程里面，需要在主线程提交给上层处理
                DispatchQueue.main.async {
                    timeout(messageID)
                }
            }
        }
    }
}
