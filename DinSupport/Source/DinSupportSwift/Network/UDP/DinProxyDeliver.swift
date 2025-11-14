//
//  DinProxyDeliver.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit
import CocoaAsyncSocket

public class DinProxyDeliver: DinDeliver {

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override init(with queue: DispatchQueue,
                         dataEncryptor: DinCommunicationEncryptor,
                         belongsTo communicationDevice: DinCommunicationDevice?,
                         from communicationIdentity: DinCommunicationIdentity) {
        super.init(with: queue, dataEncryptor: dataEncryptor, belongsTo: communicationDevice, from: communicationIdentity)

        NotificationCenter.default.addObserver(self, selector: #selector(networkDidChanged), name: .reachabilityChanged, object: nil)
    }

    /// 重写父类方法
    override func keepLive() {
        // 暂时不需要做心跳了
//        let keepLiveCom = makeServerKeepLive(success: { [weak self] (_) in
//            self?.keepLiveSuccess()
//        }, fail: { [weak self] (errMsg) in
//            self?.keepLiveFail()
//        }, timeout: { [weak self] (msgID) in
//            self?.keepLiveFail()
//        })
//        setKeepLiveCommunication(keepLiveCom)
    }

//    private func makeServerKeepLive(success: DinCommunicationCallback.SuccessBlock?,
//                                    fail: DinCommunicationCallback.FailureBlock?,
//                                    timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication? {
//        return establishConn(success: success, fail: fail, timeout: timeout)
//    }

    /// 与当前设备建立连接
//    private func establishConn(success: DinCommunicationCallback.SuccessBlock?,
//                              fail: DinCommunicationCallback.FailureBlock?,
//                              timeout: DinCommunicationCallback.TimeoutBlock?,
//                              entryCommunicator: Bool = true) -> DinCommunication? {
//        // payloadDict
//        let payloadDict = ["__time": Int64(Date().timeIntervalSince1970*1000000000)]
//        // header
//        let msctHeader = Header(msgType: .CON, channel: .NORCHAN2)
//        // optionHeader
//        var options = [OptionHeader]()
//        let userMSCTID = communicationIdentity.uniqueID
//        let msgID = String.UUID()
//        let service = "device"
//        let method = "alive"
//        let appID = DinSupport.appID ?? ""
//        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
//        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))
//        options.append(OptionHeader(id: DinMSCTOptionID.service, data: service.data(using: .utf8)))
//        options.append(OptionHeader(id: DinMSCTOptionID.method, data: method.data(using: .utf8)))
//        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: appID.data(using: .utf8)))
//
//        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(payloadDict) ?? Data(),
//                                       encryptor: dataEncryptor,
//                                       header: msctHeader,
//                                       optionHeader: options) {
//            let ackCallback = DinCommunicationCallback(successBlock: success, failureBlock: fail, timeoutBlock: timeout)
//            let params = DinAddOperationParams(with: dataEncryptor, messageID: msgID, request: request, resendTimes: nil)
//            return DinCommunicationGenerator.addOperation(with: params, ackCallback: ackCallback, resultCallback: nil, entryCommunicator: nil)
//        }
//        return nil
//    }

    // 网络改变处理, 由于自身网络的变化会导致原本soket的链接不上，所以这里需要重新链接socket
    @objc private func networkDidChanged() {
        connectToServer()
    }

    // 针对服务器给定的地址和端口，写死
    public func connectToServer() {
        connectToDestination(include: DinSupport.udpURL, port: DinSupport.udpPort)
    }

    override func checkData(_ msctData: MSCT) {
        // 过滤自身心跳包的数据
        if msctData.messageID() == keepLiveCommunication?.messageID {
            keepLiveCommunication?.msctReceived(msctData)
        } else {
            // 正常收发的数据
            // 在代理模式下，发送信息的归属设备
            var senderUniqueID = ""
            // 获取发送端的uniqueid就需要用DSMSCTOptionID.userMSCTID来获取
            if let senderData = msctData.optionHeader?[DinMSCTOptionID.sourceMSCTID]?.data,
               let groupData = msctData.optionHeader?[DinMSCTOptionID.groupMSCTID]?.data {
                // 如果是代理模式，senderUniqueID设置为发送者id
                if msctData.isProxy() {
                    senderUniqueID = DinDataConvertor.convertToString(senderData)
                } else {
                    // 如果不是代理模式，senderUniqueID设置为Groupid
                    senderUniqueID = DinDataConvertor.convertToString(groupData)
                }
                // 如果senderUniqueID 是 "SERVER"， 则是服务器发送, 由DSCore.serverControl接收
                DinSupportNotification.notifyProxyDeliverDataReceived(with: msctData, from: senderUniqueID)
            }
        }
    }
}
