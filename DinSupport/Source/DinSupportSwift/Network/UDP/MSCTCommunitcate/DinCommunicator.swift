//
//  DinCommunicator.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

public class DinCommunicator: NSObject {
    /// 数据的读写队列
    static let queue = DispatchQueue(label: DinSupportQueueName.communicatorQueue, attributes: .concurrent)
    // 用于标记的设备模型
    private weak var deviceControl: DinDeviceControl?
    // 用于生成Communication
    private(set) var communicationDevice: DinCommunicationDevice
    // 用于生成Communication的凭证
    private(set) var communicationIdentity: DinCommunicationIdentity
    /// 数据的加解密工具
    private var dataEncryptor: DinCommunicationEncryptor

    // Communication接收记录器（防止重复处理Communication）
    private let communicationRecorder = DinCommunicationRecorder()

    /// Communication数组【不能直接使用，需要搭配queue来读写以达到线程安全】
    private var unsafeCommunications: [String: DinCommunication]? = [String: DinCommunication]()
    // Communication的管理队列
    private var communications: [String: DinCommunication]? {
        var copyComms: [String: DinCommunication]?
        DinCommunicator.queue.sync { [weak self] in
            if let self = self {
                copyComms = self.unsafeCommunications
            }
        }
        return copyComms
    }
    // 其他数据包的处理器
    private var otherCommunicationHandler: DinOtherCommunicationHandler?

    deinit {
        unsafeCommunications = nil
    }

    init(with deviceControl: DinDeviceControl) {
        self.deviceControl = deviceControl
        self.communicationDevice = deviceControl.communicationDevice
        self.communicationIdentity = deviceControl.communicationIdentity
        self.dataEncryptor = deviceControl.dataEncryptor
        super.init()
        otherCommunicationHandler = DinOtherCommunicationHandler(with: communicationDevice,
                                                                 communicationIdetity: communicationIdentity,
                                                                 dataEncryptor: dataEncryptor,
                                                                 belongsTo: self)
        otherCommunicationHandler?.delegate = self
    }

    func dataReceived(_ msctData: MSCT) {
        // 如果是msct的数据包，找出messageID对应的Communication处理
        
        // 检查是否是处理过的Communication
        // 如果是ping的数据则不检测
        var isPingMSCT = false
        if let optionHeader = msctData.optionHeader?[DinMSCTOptionID.method],
           let data = optionHeader.data,
           String(data: data, encoding: .utf8) == "ping" {
            isPingMSCT = true
        }
        if !isPingMSCT && communicationRecorder.shouldAbandonMSCT(msctData) {
            // 如果是处理过的，就抛弃通讯包
//            dsLog("Communicator - shouldAbandonMSCT - \(msctData.messageID())")
            return
        }

        // 如果是没有处理过的，进入处理流程
        // 寻找是否属于自己的通讯包
        if let communication = communications?[msctData.messageID()] {
            communication.msctReceived(msctData)
        } else {
            // 如果没找到对应的communication，则进入其他信息处理逻辑
            otherCommunicationHandler?.msctReceived(msctData)
        }
    }

    private func sendData(with datas: [Data], belongsTo messageID: String) {
        deviceControl?.sendDatas(datas, belongsTo: messageID)
    }
}

// MARK: - Communication的管理方法
extension DinCommunicator: DinCommunicationDelegate {
    /// 运行操作
    ///
    /// - Parameter communication: 操作
    public func enter(communication: DinCommunication) {
        DinCommunicator.queue.async(flags: .barrier) { [weak self] in
            communication.delegate = self
            self?.unsafeCommunications?.updateValue(communication, forKey: communication.messageID)
            //加入成功之后，开始运行操作
            communication.run()
        }
    }
    /// 操作完成或者超时，请求退出
    ///
    /// - Parameter communication: 操作
    private func exit(communication: DinCommunication) {
        DinCommunicator.queue.async(flags: .barrier) { [weak self] in
            self?.unsafeCommunications?.removeValue(forKey: communication.messageID)
        }
    }

    /// 提供一种取消任务监听的手段【注意：取消了之后，不会有任何成功，失败，超时】
    /// - Parameter messageID: 任务ID
    public func forceExitCommunication(with messageID: String) {
        DinCommunicator.queue.async(flags: .barrier) { [weak self] in
            self?.unsafeCommunications?.removeValue(forKey: messageID)
        }
    }

    /// 清空任务记录队列（判断是否有重复的任务，过滤）
    public func emptyCommunicationRecords() {
        communicationRecorder.emptyRecords()
    }

    // MARK: Communication代理
    func communication(requestSendData datas: [Data], withMessageID messageID: String) {
        sendData(with: datas, belongsTo: messageID)
    }

    func communication(complete communication: DinCommunication) {
        exit(communication: communication)
    }

    func communication(ackTimeout communication: DinCommunication) {
        DinSupportNotification.notifiyAckTimeoutCommunication(with: communication)
    }
    
    func communication(requestActionResultReceived communication: DinCommunication, isProxy: Bool) {
        _ = DinCommunicationGenerator.actionResultReceived(withMessageID: communication.messageID,
                                                           isProxy: isProxy,
                                                           source: communicationIdentity,
                                                           destination: communicationDevice,
                                                           dataEncryptor: communication.dataEncryptor,
                                                           entryCommunicator: self)
    }

    func communication(_ communication: DinCommunication, requestResendPackages messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType, fileName: String?) {
        let params = DinRequestUDPPackagesParams(withMessageID: messageID,
                                                 source: communicationIdentity,
                                                 destination: communicationDevice,
                                                 indexes: indexes,
                                                 fileName: fileName,
                                                 fileType: fileType)
        _ = DinCommunicationGenerator.requestUDPPackages(params: params,
                                                        senderArea: communicationDevice.area,
                                                        dataEncryptor: communication.dataEncryptor,
                                                        entryCommunicator: self)
    }
}

// MARK: - 数据更新通知（来自第三方触发，当前接收）
extension DinCommunicator: DinOtherCommunicationHandlerDelegate {
    func requestResendData(with msctResult: DinMSCTResult) {
        let msgID = msctResult.payloadDict[DinCommunicationGenerator.messageidGetPackage] as? String ?? ""
//        dsLog("Communicator - checkResendMessage: \(msgID)")
        guard let communication = communications?[msgID] else {
            return
        }
        let packIndexs = msctResult.payloadDict[DinCommunicationGenerator.indexsGetPackage] as? [Int] ?? []

        var resendDatas = [Data]()
        if packIndexs.count > 0 {
            for i in 0 ..< packIndexs.count {
                let packIndex = packIndexs[i]
                if packIndex < communication.msctDatas.count, let data = try? communication.msctDatas[packIndex].getData() {
                    resendDatas.append(data)
                }
            }
        }
        sendData(with: resendDatas, belongsTo: msgID)
    }

    func requestThirdPartyInfoUpdate(with msctResult: DinMSCTResult) {
        deviceControl?.receiveOtherCommunicationResult(msctResult)
    }
}
