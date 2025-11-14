//
//  DinCommunicationGenerator.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

struct DinAddOperationParams {
    var dataEncryptor: DinCommunicationEncryptor
    var messageID: String
    var request: DinMSCTRequest
    /// 重发次数（如果为空，在DinCommunication定义是2s）
    var resendTimes: Int?

    init(with dataEncryptor: DinCommunicationEncryptor,
         messageID: String,
         request: DinMSCTRequest,
         resendTimes: Int?) {
        self.dataEncryptor = dataEncryptor
        self.messageID = messageID
        self.request = request
        self.resendTimes = resendTimes
    }
}

public struct DinOperateTaskParams {
    var source: DinCommunicationIdentity
    var destination: DinCommunicationDevice
    var dataEncryptor: DinCommunicationEncryptor
    var optionHeaders: [OptionHeader]?
    var messageID: String
    var sendInfo: Any?
    // 本来sendInfo如果是nil的话，会自动生成一个新的字典，这里如果是true，就直接不理了
    var ignoreSendInfoInNil: Bool

    public init(with dataEncryptor: DinCommunicationEncryptor, source: DinCommunicationIdentity, destination: DinCommunicationDevice, messageID: String, sendInfo: Any?, ignoreSendInfoInNil ignore: Bool, optionHeaders: [OptionHeader]? = nil) {
        self.dataEncryptor = dataEncryptor
        self.source = source
        self.destination = destination
        self.messageID = messageID
        self.sendInfo = sendInfo
        self.ignoreSendInfoInNil = ignore
        self.optionHeaders = optionHeaders
    }
}

public struct DinRequestUDPPackagesParams {
    var messageID: String
    var source: DinCommunicationIdentity
    var destination: DinCommunicationDevice
    var fileType: DinMSCTOptionFileType
    var fileName: String?
    var indexes: [Int]

    public init(withMessageID messageID: String, source: DinCommunicationIdentity, destination: DinCommunicationDevice, indexes: [Int], fileName: String?, fileType: DinMSCTOptionFileType) {
        self.source = source
        self.destination = destination
        self.messageID = messageID
        self.indexes = indexes
        self.fileName = fileName
        self.fileType = fileType
    }
}

public struct DinCommunicationGenerator {
    // 设备心跳包
    static let systemOnline = "SYSTEM_ONLINE"
    // 拆分包状态相关
    static let getPackage = "GET_PACKAGE"
    static let getBigFilePackage = "GET_VIDEO_SUBPACKAGE"
    static let messageidGetPackage = "big_package_msgid"
    static let indexsGetPackage = "indexs"

    /// 生成Communication，加到任务管理器Communicator
    /// - Parameters:
    ///   - params: 方法必填参数
    ///   - ackCallback: ack回调
    ///   - resultCallback: result回调
    ///   - progressCallback: 进度回调
    ///   - ackTimeoutSec: 设置任务ack超时时间
    ///   - resultTimeoutSec: 设置任务result超时时间
    ///   - entryCommunicator: 任务管理器Communicator，若有，则生成的 任务 自动添加到 任务管理器
    static func addOperation(with params: DinAddOperationParams,
                             ackCallback: DinCommunicationCallback?,
                             resultCallback: DinCommunicationCallback?,
                             progressCallback: ((Double) -> Void)? = nil,
                             ackTimeoutSec: TimeInterval = 0,
                             resultTimeoutSec: TimeInterval = 0,
                             entryCommunicator: DinCommunicator?) -> DinCommunication {
        var commParams = DinCommunicationParams(with: params.dataEncryptor,
                                                messageID: params.messageID,
                                                request: params.request,
                                                resendTimes: params.resendTimes)
        commParams.ackCallback = ackCallback
        commParams.resultCallback = resultCallback
        commParams.ackTimeoutSec = ackTimeoutSec
        commParams.resultTimeoutSec = resultTimeoutSec
        commParams.progressCallback = progressCallback

        let communicaiton = DinCommunication(with: commParams)
        entryCommunicator?.enter(communication: communicaiton)
        return communicaiton
    }

    /// 任务操作
    /// - Parameters:
    ///   - params: 方法必填参数
    ///   - payloadDic: 需要传递的payload字典
    ///   - messageID: 操作的唯一标识
    ///   - ackCallback: ack回调实例
    ///   - resultCallback: result回调实例
    ///   - progressCallback: 进度回调实例
    ///   - ackTimeoutSec: 设置任务ack超时时间
    ///   - resultTimeoutSec: 设置任务result超时时间
    ///   - entryCommunicator: 是否自动加到任务管理器Communicator
    public static func operateTask(_ params: DinOperateTaskParams,
                                   ackCallback: DinCommunicationCallback?,
                                   resultCallback: DinCommunicationCallback?,
                                   progressCallback: ((Double) -> Void)? = nil,
                                   ackTimeoutSec: TimeInterval = 0,
                                   resultTimeoutSec: TimeInterval = 0,
                                   entryCommunicator: DinCommunicator?) -> DinCommunication? {
        // header
        let msctHeader = Header(msgType: .CON, channel: .NORCHAN3)
        // optionHeader
        var options = params.optionHeaders ?? [OptionHeader]()
        let userMSCTID = params.source.uniqueID
        let groupID = params.destination.groupID
        let deviceID = params.destination.uniqueID
        let proxyData = Data(Int(1).lyz_to4Bytes())
//        let domain = params.destination.area
//        dsLog("package userMSCTID:\(userMSCTID),deviceID:\(deviceID)")
        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: (DinSupport.appID ?? "").data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: deviceID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.proxyMSCTID, data: proxyData))
//        options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: params.messageID.data(using: .utf8)))

        var sendRawData = Data()
        if let sendData = params.sendInfo as? Data {
            sendRawData = sendData
        } else if (params.sendInfo == nil && params.ignoreSendInfoInNil) {
            // 这里的data设置为空
        } else {
            // 增加触发类型
            var dataDict = (params.sendInfo as? [String: Any]) ?? [:]
    //        dataDict["triggertype"] = DinSupportConstants.triggerOperationTypeiOS
    //        dataDict["triggerid"] = params.source.id
    //        dataDict["triggername"] = params.source.name
            dataDict["__time"] = Int64(Date().timeIntervalSince1970)
            sendRawData = DinDataConvertor.convertToData(dataDict) ?? Data()
        }

        // request
        if let request = DinMSCTRequest(withRequestDict: sendRawData,
                                        encryptor: params.dataEncryptor,
                                        header: msctHeader,
                                        optionHeader: options) {
            let params = DinAddOperationParams(with: params.dataEncryptor,
                                               messageID: params.messageID,
                                               request: request,
                                               resendTimes: nil)
            return addOperation(with: params,
                                ackCallback: ackCallback,
                                resultCallback: resultCallback,
                                progressCallback: progressCallback,
                                ackTimeoutSec: ackTimeoutSec,
                                resultTimeoutSec: resultTimeoutSec,
                                entryCommunicator: entryCommunicator)
        }
        return nil
    }
}

// MARK: - 建立，撤除KCP通道
extension DinCommunicationGenerator {
    public static func establishKcpCommunication(_ params: DinOperateTaskParams,
                                                 kcpTowardsID: String,
                                                 ackCallback: DinCommunicationCallback?,
                                                 entryCommunicator: DinCommunicator?)  -> DinCommunication? {
//        let msgID = String.UUID()

        // header
        let msctHeader = Header(msgType: .CON, channel: .NORCHAN3)
        // optionHeader
        let userMSCTID = params.source.uniqueID
        let groupID = params.destination.groupID
//        let deviceID = params.destination.uniqueID

        //        let domain = params.destination.area
        //        dsLog("package userMSCTID:\(userMSCTID),deviceID:\(deviceID)")

        var options = [OptionHeader]()
        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: (DinSupport.appID ?? "").data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.method, data: "estab".data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
        if kcpTowardsID.count > 0 {
            options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: kcpTowardsID.data(using: .utf8)))
        }
        //        options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: params.messageID.data(using: .utf8)))

        // 增加触发类型
        var dataDict = (params.sendInfo as? [String: Any]) ?? [:]
        //        dataDict["triggertype"] = DinSupportConstants.triggerOperationTypeiOS
        //        dataDict["triggerid"] = params.source.id
        //        dataDict["triggername"] = params.source.name
        dataDict["__time"] = Int64(Date().timeIntervalSince1970)

        // request
        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(dataDict) ?? Data(),
                                            encryptor: params.dataEncryptor,
                                            header: msctHeader,
                                            optionHeader: options) {
            let params = DinAddOperationParams(with: params.dataEncryptor,
                                               messageID: params.messageID,
                                               request: request,
                                               resendTimes: nil)
            return DinCommunicationGenerator.addOperation(with: params,
                                                          ackCallback: ackCallback,
                                                          resultCallback: nil,
                                                          progressCallback: nil,
                                                          resultTimeoutSec: 0,
                                                          entryCommunicator: entryCommunicator)
        }
        return nil
    }

    public static func resignKcpCommunication(_ params: DinOperateTaskParams,
                                              ackCallback: DinCommunicationCallback?,
                                              entryCommunicator: DinCommunicator?)  -> DinCommunication? {
        let msgID = String.UUID()

        // header
        let msctHeader = Header(msgType: .CON, channel: .NORCHAN3)
        // optionHeader
        let userMSCTID = params.source.uniqueID
        let groupID = params.destination.groupID
        let deviceID = params.destination.uniqueID

        //        let domain = params.destination.area
        //        dsLog("package userMSCTID:\(userMSCTID),deviceID:\(deviceID)")

        var options = [OptionHeader]()
        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: (DinSupport.appID ?? "").data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.method, data: "term".data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: deviceID.data(using: .utf8)))
        //        options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))

        // 增加触发类型
        var dataDict = (params.sendInfo as? [String: Any]) ?? [:]
        //        dataDict["triggertype"] = DinSupportConstants.triggerOperationTypeiOS
        //        dataDict["triggerid"] = params.source.id
        //        dataDict["triggername"] = params.source.name
        dataDict["__time"] = Int64(Date().timeIntervalSince1970)

        // request
        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(dataDict) ?? Data(),
                                            encryptor: params.dataEncryptor,
                                            header: msctHeader,
                                            optionHeader: options) {
            let params = DinAddOperationParams(with: params.dataEncryptor,
                                               messageID: msgID,
                                               request: request,
                                               resendTimes: nil)
            return DinCommunicationGenerator.addOperation(with: params,
                                                          ackCallback: ackCallback,
                                                          resultCallback: nil,
                                                          progressCallback: nil,
                                                          resultTimeoutSec: 0,
                                                          entryCommunicator: entryCommunicator)
        }
        return nil
    }

    /// 唤醒目标设备
    public static func wake(_ params: DinOperateTaskParams,
                            targetID: String?,
                            ackCallback: DinCommunicationCallback?,
                            entryCommunicator: DinCommunicator?)  -> DinCommunication? {
        let msgID = String.UUID()

        // header
        let msctHeader = Header(msgType: .CON, channel: .NORCHAN3)
        // optionHeader
        let userMSCTID = params.source.uniqueID
        let groupID = params.destination.groupID
        let proxyData = Data(Int(1).lyz_to4Bytes())

        //        let domain = params.destination.area
        //        dsLog("package userMSCTID:\(userMSCTID),deviceID:\(deviceID)")

        var options = [OptionHeader]()
        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: (DinSupport.appID ?? "").data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.method, data: "wake".data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
        if let destinationMSCTID = targetID, destinationMSCTID.count > 0 {
            options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: destinationMSCTID.data(using: .utf8)))
        }
        options.append(OptionHeader(id: DinMSCTOptionID.proxyMSCTID, data: proxyData))
        //        options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))

        // 增加触发类型
        var dataDict = (params.sendInfo as? [String: Any]) ?? [:]
        //        dataDict["triggertype"] = DinSupportConstants.triggerOperationTypeiOS
        //        dataDict["triggerid"] = params.source.id
        //        dataDict["triggername"] = params.source.name
        dataDict["__time"] = Int64(Date().timeIntervalSince1970)

        // request
        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(dataDict) ?? Data(),
                                            encryptor: params.dataEncryptor,
                                            header: msctHeader,
                                            optionHeader: options) {
            let params = DinAddOperationParams(with: params.dataEncryptor,
                                               messageID: msgID,
                                               request: request,
                                               resendTimes: 10)
            return DinCommunicationGenerator.addOperation(with: params,
                                                          ackCallback: ackCallback,
                                                          resultCallback: nil,
                                                          progressCallback: nil,
                                                          resultTimeoutSec: 0,
                                                          entryCommunicator: entryCommunicator)
        }
        return nil
    }

    public static func heartbeat(
        _ params: DinOperateTaskParams,
        targetID: String?,
        ackCallback: DinCommunicationCallback?,
        entryCommunicator: DinCommunicator?
    ) -> DinCommunication? {
        let msgID = String.UUID()

        // header
        let msctHeader = Header(msgType: .CON, channel: .NORCHAN3)
        // optionHeader
        let userMSCTID = params.source.uniqueID
        let groupID = params.destination.groupID
        let proxyData = Data(Int(1).lyz_to4Bytes())

        //        let domain = params.destination.area
        //        dsLog("package userMSCTID:\(userMSCTID),deviceID:\(deviceID)")

        var options = [OptionHeader]()
        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: (DinSupport.appID ?? "").data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.method, data: "heartbeat".data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
        if let destinationMSCTID = targetID, destinationMSCTID.count > 0 {
            options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: destinationMSCTID.data(using: .utf8)))
        }
        options.append(OptionHeader(id: DinMSCTOptionID.proxyMSCTID, data: proxyData))
        //        options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))

        // 增加触发类型
        var dataDict = (params.sendInfo as? [String: Any]) ?? [:]
        //        dataDict["triggertype"] = DinSupportConstants.triggerOperationTypeiOS
        //        dataDict["triggerid"] = params.source.id
        //        dataDict["triggername"] = params.source.name
        dataDict["__time"] = Int64(Date().timeIntervalSince1970)

        // request
        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(dataDict) ?? Data(),
                                        encryptor: params.dataEncryptor,
                                        header: msctHeader,
                                        optionHeader: options) {
            let params = DinAddOperationParams(with: params.dataEncryptor,
                                               messageID: msgID,
                                               request: request,
                                               resendTimes: nil)
            return DinCommunicationGenerator.addOperation(with: params,
                                                          ackCallback: ackCallback,
                                                          resultCallback: nil,
                                                          progressCallback: nil,
                                                          resultTimeoutSec: 0,
                                                          entryCommunicator: entryCommunicator)
        }
        return nil
    }
}

// MARK: - P2P打洞包
extension DinCommunicationGenerator {
    /// 在获取完ipc的P2P地址之后，不断发送信息打洞
    public static func tryConnectP2P(_ params: DinOperateTaskParams,
                                     targetID: String?,
                                     ackCallback: DinCommunicationCallback?,
                                     entryCommunicator: DinCommunicator?)  -> DinCommunication? {
        let msgID = String.UUID()

        // header
        let msctHeader = Header(msgType: .CON, channel: .NORCHAN3)
        // optionHeader
//        let userMSCTID = params.source.uniqueID
//        let groupID = params.destination.groupID
        let proxyData = Data(Int(1).lyz_to4Bytes())

        //        let domain = params.destination.area
        //        dsLog("package userMSCTID:\(userMSCTID),deviceID:\(deviceID)")

        var options = [OptionHeader]()
//        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: (DinSupport.appID ?? "").data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.method, data: "ping".data(using: .utf8)))
//        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
//        options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
//        if let destinationMSCTID = targetID, destinationMSCTID.count > 0 {
//            options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: destinationMSCTID.data(using: .utf8)))
//        }
        options.append(OptionHeader(id: DinMSCTOptionID.proxyMSCTID, data: proxyData))
        //        options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))

//        print("\(Date()) DinCommunication redesign test log - msgID\(msgID) - tryConnectP2P.")
        // 增加触发类型
        var dataDict = (params.sendInfo as? [String: Any]) ?? [:]
        //        dataDict["triggertype"] = DinSupportConstants.triggerOperationTypeiOS
        //        dataDict["triggerid"] = params.source.id
        //        dataDict["triggername"] = params.source.name
        dataDict["__time"] = Int64(Date().timeIntervalSince1970)

        // request
        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(dataDict) ?? Data(),
                                        encryptor: params.dataEncryptor,
                                        header: msctHeader,
                                        optionHeader: options) {
            let params = DinAddOperationParams(with: params.dataEncryptor,
                                               messageID: msgID,
                                               request: request,
                                               resendTimes: 0)
            return DinCommunicationGenerator.addOperation(with: params,
                                                          ackCallback: ackCallback,
                                                          resultCallback: nil,
                                                          progressCallback: nil,
                                                          resultTimeoutSec: 0,
                                                          entryCommunicator: entryCommunicator)
        }
        return nil
    }

    public static func callDestinationP2P(_ params: DinOperateTaskParams,
                                          targetP2PAddress: String,
                                          targetID: String?,
                                          ackCallback: DinCommunicationCallback?,
                                          entryCommunicator: DinCommunicator?) -> DinCommunication? {
        let msgID = String.UUID()

        // header
        let msctHeader = Header(msgType: .CON, channel: .NORCHAN3)
        // optionHeader
        let userMSCTID = params.source.uniqueID
        let groupID = params.destination.groupID
        let proxyData = Data(Int(1).lyz_to4Bytes())

        //        let domain = params.destination.area
        //        dsLog("package userMSCTID:\(userMSCTID),deviceID:\(deviceID)")

        var options = [OptionHeader]()
        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: (DinSupport.appID ?? "").data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.method, data: "p2p".data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
        if let destinationMSCTID = targetID, destinationMSCTID.count > 0 {
            options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: destinationMSCTID.data(using: .utf8)))
        }
        options.append(OptionHeader(id: DinMSCTOptionID.proxyMSCTID, data: proxyData))
        //        options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))

        // 增加触发类型
        var dataDict = (params.sendInfo as? [String: Any]) ?? [:]
        //        dataDict["triggertype"] = DinSupportConstants.triggerOperationTypeiOS
        //        dataDict["triggerid"] = params.source.id
        //        dataDict["triggername"] = params.source.name
        dataDict["cmd"] = "request"
        dataDict["display_name"] = "iOS"
        dataDict["protocol"] = "kcp"
        dataDict["kcp_ipv4"] = targetP2PAddress
        dataDict["__time"] = Int64(Date().timeIntervalSince1970)

        // request
        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(dataDict) ?? Data(),
                                            encryptor: params.dataEncryptor,
                                            header: msctHeader,
                                            optionHeader: options) {
            let params = DinAddOperationParams(with: params.dataEncryptor,
                                               messageID: msgID,
                                               request: request,
                                               resendTimes: nil)
            return DinCommunicationGenerator.addOperation(with: params,
                                                          ackCallback: ackCallback,
                                                          resultCallback: nil,
                                                          progressCallback: nil,
                                                          resultTimeoutSec: 0,
                                                          entryCommunicator: entryCommunicator)
        }
        return nil
    }
}

// MARK: - 回复CON包
extension DinCommunicationGenerator {
    /// 应答设备/服务器发出的CON包，回复已经收到
    /// - Parameters:
    ///   - msgID: 包MessageID
    ///   - optionHeaders: 是否有特殊的头部
    ///   - isProxy: 是否是代理包
    ///   - senderUniqueID: 设备的UniqueID（若nil则指服务器发出的CON包）
    ///   - senderArea: 设备所在的网络区域
    ///   - dataEncryptor: 加密器
    ///   - entryCommunicator: 队列
    static func actionResultReceived(withMessageID msgID: String,
                                     optionHeaders: [OptionHeader]? = nil,
                                     isProxy: Bool,
                                     source: DinCommunicationIdentity,
                                     destination: DinCommunicationDevice?,
                                     dataEncryptor: DinCommunicationEncryptor,
                                     entryCommunicator: DinCommunicator?) -> DinCommunication? {
        // payloadDict
        let payloadDict = ["__time": Int64(Date().timeIntervalSince1970)]
        // header
        let msctHeader = Header(msgType: .ACK, channel: .NORCHAN2)
        // optionHeader
        var options = [OptionHeader]()
        if let optionHeaders = optionHeaders {
            options.append(contentsOf: optionHeaders)
        }

        if let deviceID = destination?.uniqueID, deviceID.count > 0 {
            // 设备发出的CON包处理
            let userMSCTID = source.uniqueID
            let appID = DinSupport.appID ?? ""
            let domain = destination?.area ?? ""
            let groupID = destination?.groupID ?? ""
            options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
            options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))
            options.append(OptionHeader(id: DinMSCTOptionID.appID, data: appID.data(using: .utf8)))
            options.append(OptionHeader(id: DinMSCTOptionID.status, data: Data(0.lyz_to2Bytes())))
            if isProxy {
                let proxyData = Data(Int(1).lyz_to4Bytes())
                options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
                options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
                options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: deviceID.data(using: .utf8)))
                options.append(OptionHeader(id: DinMSCTOptionID.proxyMSCTID, data: proxyData))
            } else {
                options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
                options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
            }
        } else {
            // 如果没有发送方的UniqueID，则按服务器CON包处理
            let msgID = msgID
            let appID = DinSupport.appID ?? ""
            options.append(OptionHeader(id: DinMSCTOptionID.status, data: Data(0.lyz_to2Bytes())))
            options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))
            options.append(OptionHeader(id: DinMSCTOptionID.appID, data: appID.data(using: .utf8)))
        }

        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(payloadDict) ?? Data(),
                                       encryptor: dataEncryptor,
                                       header: msctHeader,
                                       optionHeader: options) {
            let params = DinAddOperationParams(with: dataEncryptor, messageID: msgID, request: request, resendTimes: nil)
            return addOperation(with: params, ackCallback: nil, resultCallback: nil, entryCommunicator: entryCommunicator)
        }
        return nil
    }
}

// MARK: - 心跳+拆包+并包
extension DinCommunicationGenerator {
    /// 心跳包
    static func communicationDeviceKeepLive(with source: DinCommunicationIdentity,
                                            destination: DinCommunicationDevice,
                                            dataEncryptor: DinCommunicationEncryptor,
                                            success: DinCommunicationCallback.SuccessBlock?,
                                            fail: DinCommunicationCallback.FailureBlock?,
                                            timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication? {
        let msgID = String.UUID()
        let ackCallback = DinCommunicationCallback(successBlock: success, failureBlock: fail, timeoutBlock: timeout)

        var options = [OptionHeader]()
        options.append(OptionHeader(id: DinMSCTOptionID.appID, data: (DinSupport.appID ?? "").data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.method, data: "alive".data(using: .utf8)))

        // header
        let msctHeader = Header(msgType: .CON, channel: .NORCHAN3)
        // optionHeader
        let userMSCTID = source.uniqueID
        let groupID = destination.groupID
        let deviceID = destination.uniqueID
        //        let domain = params.destination.area
        //        dsLog("package userMSCTID:\(userMSCTID),deviceID:\(deviceID)")
        options.append(OptionHeader(id: DinMSCTOptionID.sourceMSCTID, data: userMSCTID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.groupMSCTID, data: groupID.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.destinationMSCTID, data: deviceID.data(using: .utf8)))
        //        options.append(OptionHeader(id: DinMSCTOptionID.domain, data: domain.data(using: .utf8)))
        options.append(OptionHeader(id: DinMSCTOptionID.msgID, data: msgID.data(using: .utf8)))

        // 增加触发类型
        var dataDict: [String: Any] = [:]
        //        dataDict["triggertype"] = DinSupportConstants.triggerOperationTypeiOS
        //        dataDict["triggerid"] = params.source.id
        //        dataDict["triggername"] = params.source.name
        dataDict["__time"] = Int64(Date().timeIntervalSince1970)

        // request
        if let request = DinMSCTRequest(withRequestDict: DinDataConvertor.convertToData(dataDict) ?? Data(),
                                        encryptor: dataEncryptor,
                                        header: msctHeader,
                                        optionHeader: options) {
        let params = DinAddOperationParams(with: dataEncryptor,
                                           messageID: msgID,
                                           request: request,
                                           resendTimes: nil)
        return addOperation(with: params,
             ackCallback: ackCallback,
             resultCallback: nil,
             progressCallback: nil,
             resultTimeoutSec: 0,
             entryCommunicator: nil)
        }
        return nil
    }

    static func requestUDPPackages(params: DinRequestUDPPackagesParams,
                                   senderArea: String?,
                                   dataEncryptor: DinCommunicationEncryptor,
                                   entryCommunicator: DinCommunicator?) -> DinCommunication? {
        if (params.fileType == .voice || params.fileType == .video) && params.fileName?.count ?? 0 < 1 {
            // 如果是大文件，但是找不到文件名，则不做任何事
            return nil
        }
        var payloadDic: [String: Any] = ["cmd": DinCommunicationGenerator.getPackage,
                                         "isall": false,
                                         DinCommunicationGenerator.indexsGetPackage: params.indexes,
                                         DinCommunicationGenerator.messageidGetPackage: params.messageID]
        if params.fileType == .voice || params.fileType == .video {
            payloadDic["cmd"] = DinCommunicationGenerator.getBigFilePackage
            payloadDic["name"] = params.fileName
        }
        let msgID = String.UUID()

        let params = DinOperateTaskParams(with: dataEncryptor,
                                          source: params.source,
                                          destination: params.destination,
                                          messageID: msgID,
                                          sendInfo: payloadDic,
                                          ignoreSendInfoInNil: false)
        return operateTask(params,
                           ackCallback: nil,
                           resultCallback: nil,
                           entryCommunicator: entryCommunicator)
    }
}
