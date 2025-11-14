//
//  DinServerControl.swift
//  DinSupport
//
//  Created by Jin on 2021/5/6.
//

import UIKit

public class DinServerControl: NSObject {
    // Communication接收记录器（防止重复处理Communication）
    private let communicationRecorder = DinCommunicationRecorder()
    /// 并包处理的超时
    private var combineDataTimeout: TimeInterval = 6.0
    /// 加解密器
    private let dataEncryptor: DinCommunicationEncryptor
    // 用于通过代理模式（服务器转发）发送MSCT的Delivery
    private(set) var proxyDeliver: DinProxyDeliver
    // 连接设备的凭证（自己）
    public private(set) var communicationIdentity: DinCommunicationIdentity
    // 数据包处理器
    private var msctHandler: DinMSCTHandler?

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 生成接受处理服务器主动推送的MSCT数据的模型
    /// - Parameters:
    ///   - dataEncryptor: 数据加解密器
    ///   - proxyDeliver: 和服务器的代理沟通器
    ///   - communicationIdentity: 连接设备的凭证（自己）   
    public init(withEncryptor dataEncryptor: DinCommunicationEncryptor, proxyDeliver: DinProxyDeliver, communicationIdentity: DinCommunicationIdentity) {
        self.dataEncryptor = dataEncryptor
        self.proxyDeliver = proxyDeliver
        self.communicationIdentity = communicationIdentity
        super.init()
        msctHandler = DinMSCTHandler(with: dataEncryptor,combineAckPackTimeout: combineDataTimeout, resultTimeout: combineDataTimeout)
        msctHandler?.delegate = self
    }

    func config() {
        // 系统的UDP代理模式通道收到的MSCT包
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(receivedServerData(_:)),
                                               name: .dinProxyDeliverDataReceived,
                                               object: nil)
    }

    // 系统的UDP代理模式通道收到的MSCT包
    @objc private func receivedServerData(_ notif: Notification) {
        guard let msctData = notif.userInfo?[DinSupportNotificationKey.dinMSCTDataKey] as? MSCT else {
            return
        }
        // 检查是否是属于本设备的消息
        let senderUniqueID = notif.userInfo?[DinSupportNotificationKey.dinMSCTIDKey] as? String ?? ""
        guard senderUniqueID == "SERVER" else {
            return
        }
        // 处理消息
        handleMSCT(msctData)
    }

    private func handleMSCT(_ msctData: MSCT) {
        // 检查是否是处理过的Communication, 如果是处理过的，就抛弃通讯包
        if communicationRecorder.shouldAbandonMSCT(msctData) {
            return
        }
        msctHandler?.receiveMSCT(msctData)
    }

    /// 清空任务记录队列（判断是否有重复的任务，过滤）
    public func emptyCommunicationRecords() {
        communicationRecorder.emptyRecords()
    }
}

extension DinServerControl: DinMSCTHandlerDelegate {
    func package(percentageOfCompletion percentage: Double) {
        //
    }

//    case DinDeviceControl.serverNotifyResetDevice // 收到设备被重置的通知
//    case DinDeviceControl.kickedByOthers // 收到自己被别的用户剔除出设备的通知
    func completePackage(_ result: DinMSCTResult) {
        if result.type == .CON {
            // 获取到设备的result返回之后发送ack确认给设备
            if let comm = DinCommunicationGenerator.actionResultReceived(withMessageID: result.messageID,
                                                                         isProxy: result.isProxyMSCT,
                                                                         source: communicationIdentity,
                                                                         destination: nil,
                                                                         dataEncryptor: dataEncryptor,
                                                                         entryCommunicator: nil) {
                var datas = [Data]()
                for msct in comm.msctDatas {
                    if let data = try? msct.getData() {
                        datas.append(data)
                    }
                }
                proxyDeliver.sendDatas(datas, messageID: comm.messageID)
            }
        }

//        dsLog("====== didReceived server message: \(result.messageID)\nresult: \(result.payloadDict)")
//        let cmd = result.payloadDict["cmd"] as? String ?? ""

       DinSupportNotification.postServerIncomeInfo(with: result)
    }

    func requestResendPackages(with messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType) {
        // server 端暂时不处理
    }
}
