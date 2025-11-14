//
//  DinCommunicationDevice.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

public protocol DinCommunicationDevice {
    /// 设备ID
    var deviceID: String { get }

    /// 设备通讯ID
    var uniqueID: String { get }

    /// 所在的通讯群组id
    var groupID: String { get }

    /// 设备通讯Key
    var token: String { get }

    /// 设备通讯的区域
    var area: String { get }

    /// p2p通讯不需要对象记录，在DinDeviceControl里面保管
//    /// 设备通讯的P2P地址（包含端口）
//    var p2pAddress: String { get set }
//    /// 设备通讯的局域网地址端口
//    var p2pPort: UInt16 { get }

    /// 设备通讯的局域网地址
    var lanAddress: String { get set }
    /// 设备通讯的局域网地址端口
    var lanPort: UInt16 { get set }
}
