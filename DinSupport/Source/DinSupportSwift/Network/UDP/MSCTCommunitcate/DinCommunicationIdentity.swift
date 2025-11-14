//
//  DinCommunicationIdentity.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

/// 通过MSCT协议通讯的身份（自己）
public protocol DinCommunicationIdentity {
    /// 通讯者ID
    var id: String { get }

    /// 通讯者的通讯ID
    var uniqueID: String { get }
    /// 通讯者的通讯加密key
    var communicateKey: String { get }
    /// 所在的通讯群组id
    var groupID: String { get }

    /// 通讯者名字
    var name: String { get }
}
