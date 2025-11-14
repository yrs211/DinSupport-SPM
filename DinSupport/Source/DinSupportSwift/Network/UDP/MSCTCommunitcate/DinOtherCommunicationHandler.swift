//
//  DinOtherCommunicationHandler.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

protocol DinOtherCommunicationHandlerDelegate: NSObjectProtocol {
    /// 设备请求重发拆包的数据
    /// - Parameter msctResult: 请求重发的包相关信息
    func requestResendData(with msctResult: DinMSCTResult)
    /// 数据更新通知（来自第三方触发，当前接收）
    /// - Parameter msctResult: 相关的信息数据包
    func requestThirdPartyInfoUpdate(with msctResult: DinMSCTResult)
}

class DinOtherCommunicationHandler: NSObject {
    weak var delegate: DinOtherCommunicationHandlerDelegate?
    /// OtherCommunication对应的设备沟通器
    private weak var communicator: DinCommunicator?
    /// OtherCommunication对应的设备
    private var communicationDevice: DinCommunicationDevice
    /// OtherCommunication对应的自己
    private var communicationIdentity: DinCommunicationIdentity
    /// 数据的加解密工具
    private var dataEncryptor: DinCommunicationEncryptor
    /// 并包处理的超时
    private var combineDataTimeout: TimeInterval = 6.0
    // 数据包处理器
    private var msctHandler: DinMSCTHandler?

    init(with communicationDevice: DinCommunicationDevice,
         communicationIdetity: DinCommunicationIdentity,
         dataEncryptor: DinCommunicationEncryptor,
         belongsTo communicator: DinCommunicator) {
        self.communicationDevice = communicationDevice
        self.communicationIdentity = communicationIdetity
        self.dataEncryptor = dataEncryptor
        self.communicator = communicator
        super.init()
        msctHandler = DinMSCTHandler(with: self.dataEncryptor, combineAckPackTimeout: combineDataTimeout, resultTimeout: combineDataTimeout)
        msctHandler?.delegate = self
    }

    /// 接收msct数据包
    ///
    /// - Parameter msct: msct数据包
    public func msctReceived(_ msct: MSCT) {
//        dsLog("Communication - msctReceived: \(msct.messageID())\n\(msct.header)")
        msctHandler?.receiveMSCT(msct)
    }
}

extension DinOtherCommunicationHandler: DinMSCTHandlerDelegate {
    func package(percentageOfCompletion percentage: Double) {
        //
    }

    func completePackage(_ result: DinMSCTResult) {
//        dsLog("Communication(\(result.messageID)) - completePackage:  - \(result.payloadDict)")
        if result.type == .CON, let entryCommunicator = communicator {
            // 获取到设备的result返回之后发送ack确认给设备
            var neededOptionHeaders: [OptionHeader]?
            // 如果有seq，原封不动搬运
            if let optionHeader = result.msctDatas.first?.optionHeader?[DinMSCTOptionID.seq] {
                neededOptionHeaders = [OptionHeader]()
                neededOptionHeaders?.append(optionHeader)
            }
            _ = DinCommunicationGenerator.actionResultReceived(withMessageID: result.messageID,
                                                               optionHeaders: neededOptionHeaders,
                                                               isProxy: result.isProxyMSCT,
                                                               source: communicationIdentity,
                                                               destination: communicationDevice,
                                                               dataEncryptor: dataEncryptor,
                                                               entryCommunicator: entryCommunicator)
        }

//        dsLog("====== didReceived other message: \(result.messageID)\nresult: \(result.payload)")
        let cmd = result.payloadDict["cmd"] as? String ?? ""
//        dsLog("====== didReceived other message and cmd:\(cmd)")

        switch cmd {
        case DinCommunicationGenerator.getPackage:
            // 设备请求重发拆包的数据
            delegate?.requestResendData(with: result)
        default:
            delegate?.requestThirdPartyInfoUpdate(with: result)
        }
    }

    func requestResendPackages(with messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType) {
        let params = DinRequestUDPPackagesParams(withMessageID: messageID,
                                                source: communicationIdentity,
                                                destination: communicationDevice,
                                                indexes: indexes,
                                                fileName: nil,
                                                fileType: fileType)
        _ = DinCommunicationGenerator.requestUDPPackages(params: params,
                                                        senderArea: communicationDevice.area,
                                                        dataEncryptor: dataEncryptor,
                                                        entryCommunicator: communicator)
    }
}
