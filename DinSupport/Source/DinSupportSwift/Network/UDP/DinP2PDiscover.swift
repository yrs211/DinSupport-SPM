//
//  DinP2PDiscover.swift
//  DinSupport
//
//  Created by Jin on 2021/8/6.
//

import Foundation
import CocoaAsyncSocket
import DinSupportObjC
class DinP2PDiscover: NSObject {
    /// 生成获取本机P2P通道的公网地址请求数据
    /// - Returns: 请求数据
    class func genGetSelfP2PAddressRequestData() -> Data {
        let requestData = NSData(bytes: [0x67] as [UInt8], length: 1)
        return Data(requestData)
    }

    let p2pDeliver: DinDeliver
    var connectTargetParams: DinOperateTaskParams

    var handshakeKcp: KCPObject?

    // 加解密工具
    let dataEncryptor: DinCommunicationEncryptor
    // 数据包处理器
    private var msctHandler: DinMSCTHandler?

    var unsafeComms: [String: DinCommunication]? = [String: DinCommunication]()

    static let commQueue = DispatchQueue(label: DinSupportQueueName.deviceP2pComm)

    private var completeBlock: ((Bool)->())?

    var sendTimer: DinGCDTimer?
    var timeoutTimer: DinGCDTimer?

    /// 对端通讯的P2P地址（包含端口）
    var targetP2PAddress: String = ""
    /// 对端通讯的局域网地址端口
    var targetP2PPort: UInt16 = 0
    /// 和IPC打洞的约定id
    var handShakeID: UInt32 = 0

    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }

    /// 开始尝试打洞
    /// - Parameters:
    ///   - udpSocket: 用于打洞的Socket
    ///   - connectTargetParams: 打洞的对端信息
    init?(withP2PDeliver p2pDeliver: DinDeliver, dataEncryptor: DinCommunicationEncryptor, connectTargetParams: DinOperateTaskParams) {
        guard
            let genConvID = DinKCPConvUtil.convWithType(.p2pHandShake, sessionID: DinKCPConvUtil.genSessionID()) else {
            return nil
        }
        self.p2pDeliver = p2pDeliver
        self.dataEncryptor = dataEncryptor
        self.connectTargetParams = connectTargetParams
        super.init()
        // 用于处理ipc主动发过来的打洞MSCT
        // 处理数据包的timeout定位2s，足够了，只有一个包, 不做并包
        msctHandler = DinMSCTHandler(with: self.dataEncryptor, combineAckPackTimeout: 2, resultTimeout: 2)
        msctHandler?.delegate = self
        // 生成请求Kcp
        handshakeKcp = KCPObject(convID: genConvID, outputDataHandle: { [weak self] outpuData in
            guard let self = self else { return  -1 }
            self.p2pDeliver.sendRawData(outpuData)
            return 0
        })
        handshakeKcp?.delegate = self
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(receiveKcpData(_:)),
                                               name: .dinProxyDeliverKcpDataReceived,
                                               object: nil)
    }

    func beginP2PConnect(timeoutSec: Int = 12, targetIP: String, targetPort: UInt16, handShakeID: UInt32, complete: ((Bool)->())?) {
        // 在主线程保证timer安全
        DinP2PDiscover.commQueue.async { [weak self] in
            self?.targetP2PAddress = targetIP
            self?.targetP2PPort = targetPort
            self?.handShakeID = handShakeID

            // 重新连接Lan
            self?.p2pDeliver.connectToDestination(include: targetIP, port: targetPort)

            self?.completeBlock = complete
            self?.startTimer(timeoutSec: timeoutSec)
        }
    }

    private func genhandShakeData(complete: Bool) -> Data? {
        // {"cmd":"request", "display_name":"iOS-14.1","protocol":"kcp,quic","kcp_ipv4":"202.168.16.15:3321","quic_ipv4":"202.168.16.15:3322"}
        var dataDict: [String: Any] = [:]
        dataDict["cmd"] = complete ? "connected" : "connecting"
        dataDict["display_name"] = "iOS"
        dataDict["connect_id"] = handShakeID
        return dataEncryptor.encryptedKcpData(DinDataConvertor.convertToData(dataDict) ?? Data())
    }

    @objc private func receiveKcpData(_ notif: Notification) {
        guard let data = notif.userInfo?[DinSupportNotificationKey.dinKCPDataKey] as? Data else {
            return
        }
        // 检查是否是属于本设备的消息
        let convString = notif.userInfo?[DinSupportNotificationKey.dinKCPIDKey] as? String ?? ""

        DinP2PDiscover.commQueue.async { [weak self] in
            guard self?.handshakeKcp?.convString == convString else {
                return
            }
            // 处理消息
            self?.handshakeKcp?.inputData(data)
        }
    }

    private func genComm() {
        let callback = DinCommunicationCallback(successBlock: { [weak self] _ in
            // success
            self?.commDidResponse()
        }, failureBlock: nil, timeoutBlock: nil)

        // 添加新的任务ID
        let params = DinOperateTaskParams(with: self.connectTargetParams.dataEncryptor,
                                          source: self.connectTargetParams.source,
                                          destination: self.connectTargetParams.destination,
                                          messageID: String.UUID(),
                                          sendInfo: self.connectTargetParams.sendInfo,
                                          ignoreSendInfoInNil: false)

        if let comm = DinCommunicationGenerator.tryConnectP2P(params,
                                                              targetID: params.destination.uniqueID,
                                                              ackCallback: callback,
                                                              entryCommunicator: nil) {
            self.unsafeComms?[comm.messageID] = comm
            comm.delegate = self
            comm.run()
        }
    }

    private func commDidResponse() {
        DinP2PDiscover.commQueue.async { [weak self] in
            guard let self = self else { return }
            // 保证timer安全
            self.stopTimer()
            self.completeBlock?(true)
            self.completeBlock = nil
            self.unsafeComms?.removeAll()
        }
    }
}

// 计时器
extension DinP2PDiscover {
    private func startTimer(timeoutSec: Int) {
        stopTimer()
        // 发送计时器
        var isBegin = false
        sendTimer = DinGCDTimer(timerInterval: .seconds(2), isRepeat: true, executeBlock: { [weak self] in
//            self?.genComm()
            if let kcpData = self?.genhandShakeData(complete: false) {
                self?.handshakeKcp?.send(kcpData)
                if !isBegin {
                    self?.handshakeKcp?.startReceiving()
                }
                isBegin = true
            }
        }, queue: DinP2PDiscover.commQueue)
        // 超时计时器
        timeoutTimer = DinGCDTimer(timerInterval: .seconds(Double(timeoutSec)), isRepeat: true, executeBlock: { [weak self] in
            self?.stopTimer()
            self?.completeBlock?(false)
            self?.completeBlock = nil
        }, queue: DinP2PDiscover.commQueue)
    }

    private func stopTimer() {
        sendTimer = nil
        timeoutTimer = nil
    }

    func receivePing(data: MSCT) {
//        DinP2PDiscover.commQueue.async { [weak self] in
//            let msgID = data.messageID()
//            // 查询是否有对应的Communication
//            if let comm = self?.unsafeComms?[msgID] {
//                comm.msctReceived(data)
//            } else {
//                // 如果没有的话，就是ipc发过来的第三方包
//                self?.msctHandler?.receiveMSCT(data)
//            }
//        }
    }
}

extension DinP2PDiscover: DinCommunicationDelegate {
    func communication(requestSendData datas: [Data], withMessageID messageID: String) {
        p2pDeliver.sendDatas(datas, messageID: messageID, toHost: self.targetP2PAddress, port: self.targetP2PPort)
    }

    func communication(complete communication: DinCommunication) {
        //
    }

    func communication(ackTimeout communication: DinCommunication) {
        //
    }

    func communication(requestActionResultReceived communication: DinCommunication, isProxy: Bool) {
        // 这里只要是利用DinCommunication打包需要的data发送给设备
        guard let comm = DinCommunicationGenerator.actionResultReceived(withMessageID: communication.messageID,
                                                                        isProxy: isProxy,
                                                                        source: connectTargetParams.source,
                                                                        destination: connectTargetParams.destination,
                                                                        dataEncryptor: communication.dataEncryptor,
                                                                        entryCommunicator: nil) else {
            return
        }

        var datas = [Data]()
        for msct in comm.msctDatas {
            if let data = try? msct.getData() {
                datas.append(data)
            }
        }
        p2pDeliver.sendDatas(datas, messageID: comm.messageID)
    }

    func communication(_ communication: DinCommunication, requestResendPackages messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType, fileName: String?) {
        // 这里只要是利用DinCommunication打包需要的data发送给设备
        let params = DinRequestUDPPackagesParams(withMessageID: messageID,
                                                 source: connectTargetParams.source,
                                                 destination: connectTargetParams.destination,
                                                 indexes: indexes,
                                                 fileName: fileName,
                                                 fileType: fileType)
        guard let comm = DinCommunicationGenerator.requestUDPPackages(params: params,
                                                                      senderArea: connectTargetParams.destination.area,
                                                                      dataEncryptor: communication.dataEncryptor,
                                                                      entryCommunicator: nil) else {
            return
        }

        var datas = [Data]()
        for msct in comm.msctDatas {
            if let data = try? msct.getData() {
                datas.append(data)
            }
        }
        p2pDeliver.sendDatas(datas, messageID: comm.messageID)
    }
}

extension DinP2PDiscover: DinMSCTHandlerDelegate {
    func completePackage(_ result: DinMSCTResult) {
        if result.type == .CON {
            // 获取到设备的result返回之后发送ack确认给设备
            var neededOptionHeaders: [OptionHeader]?
            // 如果有seq，原封不动搬运
            if let optionHeader = result.msctDatas.first?.optionHeader?[DinMSCTOptionID.seq] {
                neededOptionHeaders = [OptionHeader]()
                neededOptionHeaders?.append(optionHeader)
            }
            let comm = DinCommunicationGenerator.actionResultReceived(withMessageID: result.messageID,
                                                               optionHeaders: neededOptionHeaders,
                                                               isProxy: result.isProxyMSCT,
                                                               source: connectTargetParams.source,
                                                               destination: connectTargetParams.destination,
                                                               dataEncryptor: dataEncryptor,
                                                               entryCommunicator: nil)
            comm?.delegate = self
            comm?.run()
        }
    }

    func package(percentageOfCompletion percentage: Double) {
    }

    func requestResendPackages(with messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType) {
        // 不处理并包逻辑，这个只是打洞数据包
    }
}

extension DinP2PDiscover: KCPObjectDelegate {
    func kcp(_ kcp: KCPObject, didReceivedData data: Data) {
        if let decryptData = dataEncryptor.decryptedKcpData(data),
            let decryptDict = DinDataConvertor.convertToDictionary(decryptData) {
            if decryptDict["cmd"] as? String == "connected" {
                DinP2PDiscover.commQueue.async { [weak self] in
                    guard let self = self else { return }
                    // 保证timer安全
                    if let kcpData = self.genhandShakeData(complete: true) {
                        self.handshakeKcp?.send(kcpData)
                    }
                    self.stopTimer()
                    self.completeBlock?(true)
                    self.completeBlock = nil
                }
            }
        }
    }

    func kcpDidReceivedResetRequest(_ kcp: KCPObject) {
        //
    }
}
