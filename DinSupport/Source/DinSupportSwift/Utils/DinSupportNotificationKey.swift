//
//  DinSupportNotificationKey.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

open class DinSupportNotificationKey: NSObject {
    /// MSCT包的结果
    public static let dinMSCTResultKey = Notification.Name.addPrefixToNotificationName("MSCTResultKey")
    /// UDP操作的Communication
    static let dinCommunicationKey = Notification.Name.addPrefixToNotificationName("CommunicationKey")
    /// UDP操作的MSCT Data
    static let dinMSCTDataKey = Notification.Name.addPrefixToNotificationName("MSCTDataKey")
    /// UDP操作的设备通讯唯一ID, uniqueid/msctid
    public static let dinMSCTIDKey = Notification.Name.addPrefixToNotificationName("MSCTIDKey")
    /// 通过UDP连接的设备
    public static let dinUDPCommunicationDeviceKey = Notification.Name.addPrefixToNotificationName("UDPCommunicationDeviceKey")
    /// 通过UDP连接的设备的网络状态
    public static let dinUDPCommunicationDeviceStateKey = Notification.Name.addPrefixToNotificationName("UDPCommunicationDeviceStateKey")
    /// UDP操作的kcp Data
    public static let dinKCPDataKey = Notification.Name.addPrefixToNotificationName("KCPDataKey")
    /// UDP通讯的kcp conv
    public static let dinKCPIDKey = Notification.Name.addPrefixToNotificationName("KCPIDKey")
}
