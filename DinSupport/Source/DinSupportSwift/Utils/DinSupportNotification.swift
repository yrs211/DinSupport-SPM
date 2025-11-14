//
//  DinSupportNotification.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

extension Notification.Name {
    /// 防止命名重复
    public static func addPrefixToNotificationName(_ notiName: String) -> String {
        return "DinSupport" + notiName
    }
    /// DinMSCTHandler组包成功之后全局通知.
    // userinfo - [DinSupportNotificationKey.dinMSCTResultKey: DinMSCTResult]
    static let dinMSCTPackCompleted = Notification.Name(addPrefixToNotificationName("MSCTPackCompleted"))
    /// DinCommunicator 收到了 DinCommunication里面的ACK-timeout回调之后，全局通知.
    /// userinfo - [DinSupportNotificationKey.dinCommunicationKey: DinCommunication]
    static let dinCommunicationAckTimeout = Notification.Name(addPrefixToNotificationName("CommunicationAckTimeout"))
    /// 系统的UDP代理模式通道收到的MSCT包.
    /// userinfo - [DinSupportNotificationKey.dinMSCTDataKey: MSCT, DinSupportNotificationKey.dinMSCTIDKey: String]
    /// proxyUniqueID - 在代理模式下，发送信息的归属设备
    static let dinProxyDeliverDataReceived = Notification.Name(addPrefixToNotificationName("ProxyDeliverDataReceived"))
    /// 系统的UDP代理模式通道收到的kcpData
    /// userinfo - [DinSupportNotificationKey.dinKCPDataKey: Data, DinSupportNotificationKey.dinKCPIDKey: String]
    /// proxyUniqueID - 在代理模式下，发送信息的归属设备
    public static let dinProxyDeliverKcpDataReceived = Notification.Name(addPrefixToNotificationName("ProxyDeliverKcpDataReceived"))
    /// 设备信息修改了(SET_SYSTEM_STATUS, GET_SYSTEM_STATUS)之后，检查p2p和lan的通道是否有变.
    /// userinfo - [DinSupportNotificationKey.dinMSCTIDKey: String]
    static let dinDeviceDeliverHostCheck = Notification.Name(addPrefixToNotificationName("DeviceDeliverHostCheck"))
    /// 收到设备状态需要更新的请求
    /// userinfo - [DinSupportNotificationKey.dinUDPCommunicationDeviceKey: DinCommunicationDevice, DinSupportNotificationKey.dinUDPCommunicationDeviceStateKey: DinDeviceControlNetworkState]
    public static let dinDeviceNetworkState = Notification.Name(addPrefixToNotificationName("DeviceNetworkState"))
    /// 收到服务器需要更新信息的请求
    /// userinfo - [DinSupportNotificationKey.dinMSCTResultKey: DinMSCTResult]
    static let dinServerIncomeInfo = Notification.Name(addPrefixToNotificationName("ServerIncomeInfo"))
}

public struct DinSupportNotification {
    public static func postInfo(with postName: NSNotification.Name, info: [String: Any]?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: postName, object: nil, userInfo: info)
        }
    }

    /// DinMSCTHandler组包成功之后全局通知.
    /// - Parameter msctResult: 组包成功的结果
    static func notifyCompleteMSCTPack(with msctResult: DinMSCTResult) {
        NotificationCenter.default.post(name: .dinMSCTPackCompleted,
                                        object: nil,
                                        userInfo: [DinSupportNotificationKey.dinMSCTResultKey: msctResult])
    }

    /// ACK超时的Communication 通知
    /// - Parameter communication: 通讯模型
    static func notifiyAckTimeoutCommunication(with communication: DinCommunication) {
        NotificationCenter.default.post(name: .dinCommunicationAckTimeout,
                                        object: nil,
                                        userInfo: [DinSupportNotificationKey.dinCommunicationKey: communication])
    }

    /// 系统的UDP代理模式通道收到的MSCT包.
    /// - Parameters:
    ///   - msctData: MSCT包
    ///   - uniqueID: 发送端的MSCTID
    static func notifyProxyDeliverDataReceived(with msctData: MSCT, from uniqueID: String) {
        NotificationCenter.default.post(name: .dinProxyDeliverDataReceived,
                                        object: nil,
                                        userInfo: [DinSupportNotificationKey.dinMSCTDataKey: msctData,
                                                   DinSupportNotificationKey.dinMSCTIDKey: uniqueID])
    }

    /// 系统的UDP代理模式通道收到的kcp包.
    /// - Parameters:
    ///   - kcpData: kcp data
    ///   - convString: kcp data conv
    static func notifyProxyDeliverKcpDataReceived(with kcpData: Data, from convString: String) {
        NotificationCenter.default.post(name: .dinProxyDeliverKcpDataReceived,
                                        object: nil,
                                        userInfo: [DinSupportNotificationKey.dinKCPDataKey: kcpData,
                                                   DinSupportNotificationKey.dinKCPIDKey: convString])
    }

    /// 设备信息修改了(SET_SYSTEM_STATUS, GET_SYSTEM_STATUS)之后，检查p2p和lan的通道是否有变.
    /// - Parameter msctID: 发送端的MSCTID
    public static func notifyCheckDeviceDeliverHost(with msctID: String) {
        NotificationCenter.default.post(name: .dinDeviceDeliverHostCheck,
                                        object: nil,
                                        userInfo: [DinSupportNotificationKey.dinMSCTIDKey: msctID])
    }

    /// 收到设备状态需要更新的请求
    /// - Parameters:
    ///   - communicationDevice: 需要更新的设备
    ///   - networkState: 网络状态
    static func postNetworkState(with communicationDevice: DinCommunicationDevice, networkState: DinDeviceControlNetworkState) {
        NotificationCenter.default.post(name: .dinDeviceNetworkState,
                                        object: nil,
                                        userInfo: [DinSupportNotificationKey.dinUDPCommunicationDeviceKey: communicationDevice,
                                                   DinSupportNotificationKey.dinUDPCommunicationDeviceStateKey: networkState])
    }

    /// 通知服务器主动发到APP的MSCT信息
    /// - Parameter result: MSCT信息
    static func postServerIncomeInfo(with result: DinMSCTResult) {
        NotificationCenter.default.post(name: .dinServerIncomeInfo,
                                        object: nil,
                                        userInfo: [DinSupportNotificationKey.dinMSCTResultKey: result])
    }
}
