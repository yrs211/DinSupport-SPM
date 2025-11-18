//
//  DinDeliver.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit
import CocoaAsyncSocket
import DinSupportObjC
protocol DinDeliverDataSource: NSObjectProtocol {
    /// 沟通器请求心跳逻辑
    /// 请根据给出的成功、失败、超时回调，新建一个DinCommunication实例传入沟通器
    /// - Parameters:
    ///   - deliver: 沟通器
    ///   - success: 成功回调（用于新建DinCommunication实例）
    ///   - fail: 失败回调（用于新建DinCommunication实例）
    ///   - timeout: 超时回调（用于新建DinCommunication实例）
    func deliver(requestKeepliveCommunication deliver: DinDeliver,
                 withSuccess success: DinCommunicationCallback.SuccessBlock?,
                 fail: DinCommunicationCallback.FailureBlock?,
                 timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication?
}

protocol DinDeliverDelegate: NSObjectProtocol {
    // 通道数据交换方法
    func deliver(_ deliver: DinDeliver, didReceiveData msctData: MSCT)
    // 独立出来的P2P地址
    func deliver(_ deliver: DinDeliver, didReceiveP2PAddress p2pAddress: String, p2pPort: UInt16)
    // 独立出来的P2P 打洞数据包
    func deliver(_ deliver: DinDeliver, didReceiveP2PPingData msctData: MSCT)
    // 通道是否可用
    func deliverAvailable(_ deliver: DinDeliver)
    func deliverUnavailable(_ deliver: DinDeliver)
    // 通道是否连通
    func deliverConnected(_ deliver: DinDeliver)
    func deliverLost(_ deliver: DinDeliver)
}

public class DinDeliver: NSObject {
    /// 并行记录本通道相关属性 queue
    static let motifyPropertyQueue = DispatchQueue(label: DinSupportQueueName.deliverMotifyProperty, attributes: .concurrent)
    /// 数据的读写队列
    static let keepLiveTimerQueue = DispatchQueue(label: DinSupportQueueName.keepLiveTimer, attributes: .concurrent)

    /// 数据请求
    weak var deliverDataSource: DinDeliverDataSource?
    /// 代理
    weak var deliverDelegate: DinDeliverDelegate?
    /// 通道归属设备(用于获取设备的信息，来做对应设备的心跳)
    // 如果子类不需要(例如DinProxyDeliver仅仅是和服务器沟通)，可为空
    private(set) var communicationDevice: DinCommunicationDevice?
    /// 通讯凭证（自己）
    private(set) var communicationIdentity: DinCommunicationIdentity
    /// 数据的加解密工具
    let dataEncryptor: DinCommunicationEncryptor

    /// 心跳包时间，收到心跳包50s，心跳包超时15s
    static private let keepLiveReceivedSec: TimeInterval = 50
    static private let KeepLiveTimeoutSec: TimeInterval = 15
    private var keepLiveTime: TimeInterval = DinDeliver.KeepLiveTimeoutSec
    // 心跳包失败次数超过规定时，重连失败再弹离线
    private var unsafeKeepLiveFailCount: Int = 0
    private var keepLiveFailCount: Int {
        var copyCount: Int = 0
        DinDeliver.motifyPropertyQueue.sync { [weak self] in
            if let self = self {
                copyCount = self.unsafeKeepLiveFailCount
            }
        }
        return copyCount
    }
    private let keepLiveFailTotal: Int = 3
    // 发送心跳包保持连接服务器的计时器
    private var unsafeKeepLiveTimer: DinGCDTimer?
    private var keepLiveTimer: DinGCDTimer? {
        var copyTimer: DinGCDTimer?
        DinDeliver.keepLiveTimerQueue.sync { [weak self] in
            if let self = self {
                copyTimer = self.unsafeKeepLiveTimer
            }
        }
        return copyTimer
    }

    /// keepLiveCommunication的读写队列
    static let keepLiveCommunicationQueue = DispatchQueue(label: DinSupportQueueName.keepLiveCommunication, attributes: .concurrent)
    /// 记录keeplive的Communication【不能直接使用，需要搭配DinDeliver.keepLiveCommunicationQueue来读写以达到线程安全】
    private var unsafeKeepLiveCommunication: DinCommunication?
    // 发送心跳包使用的通信对象
    var keepLiveCommunication: DinCommunication? {
        var copyComm: DinCommunication?
        DinDeliver.keepLiveCommunicationQueue.sync { [weak self] in
            if let self = self {
                copyComm = self.unsafeKeepLiveCommunication
            }
        }
        return copyComm
    }

    // UDP Socket 需要用到的Queue
    private var socketQueue: DispatchQueue
    private(set) var socket: GCDAsyncUdpSocket?
    // 连接部分需要的ip
    private(set) var ipAdress: String = ""
    // 连接部分需要的端口
    private(set) var port: UInt16 = 0

    /// 是否可用（供任务使用）
    private(set) var unsafeAvailable = false {
        didSet {
            // 设置完成之后，询问属性最新的值
            if unsafeAvailable {
                deliverDelegate?.deliverAvailable(self)
            } else {
                deliverDelegate?.deliverUnavailable(self)
            }
        }
    }
    var available: Bool {
        var copyAvailable = false
        DinDeliver.motifyPropertyQueue.sync { [weak self] in
            if let self = self {
                copyAvailable = self.unsafeAvailable
            }
        }
        return copyAvailable
    }

    /// 是否连接成功（心跳包决定的）
    private(set) var unsafeIsConnected = false {
        didSet {
            // 设置完成之后，询问属性最新的值
            if unsafeIsConnected {
                deliverDelegate?.deliverConnected(self)
            } else {
                deliverDelegate?.deliverLost(self)
            }
        }
    }
    var isConnected: Bool {
        var copyConnected = false
        DinDeliver.motifyPropertyQueue.sync { [weak self] in
            if let self = self {
                copyConnected = self.unsafeIsConnected
            }
        }
        return copyConnected
    }

    // 收发的任务IDs
    private var unsafeSendMessageIDs = [String]()
    // 从通道收发的任务ID
    private var sendMessageIDs: [String] {
        var copyMsgIDs = [String]()
        DinDeliver.motifyPropertyQueue.sync { [weak self] in
            if let self = self {
                copyMsgIDs = self.unsafeSendMessageIDs
            }
        }
        return copyMsgIDs
    }

    deinit {
        unsafeKeepLiveTimer = nil
        unsafeKeepLiveCommunication = nil
        NotificationCenter.default.removeObserver(self)
    }

    /// UDP通道
    /// - Parameters:
    ///   - queue: 绑定的队列
    ///   - dataEncryptor: 通讯需要的加密解密器
    ///   - communicationDevice: 通道归属设备(用于获取设备的信息，来做对应设备的心跳) - 如果子类不需要(例如DinProxyDeliver仅仅是和服务器沟通)，可为空
    init(with queue: DispatchQueue, dataEncryptor: DinCommunicationEncryptor, belongsTo communicationDevice: DinCommunicationDevice?, from communicationIdentity: DinCommunicationIdentity) {
        self.communicationDevice = communicationDevice
        self.communicationIdentity = communicationIdentity
        self.dataEncryptor = dataEncryptor
        self.socketQueue = queue
        super.init()

        /// 订阅从Communicator.swift整理后，确定ack timeout的任务
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleCommunicationAckTimeout(_:)),
                                               name: .dinCommunicationAckTimeout,
                                               object: nil)
    }

    @objc private func handleCommunicationAckTimeout(_ notif: Notification) {
        if let comm = notif.userInfo?[DinSupportNotificationKey.dinCommunicationKey] as? DinCommunication {
            /// 安全操作线程
            DinDeliver.motifyPropertyQueue.async(flags: .barrier) { [weak self] in
                guard let taskIDs = self?.unsafeSendMessageIDs else {
                    return
                }
                if taskIDs.contains(comm.messageID) {
                    self?.unsafeAvailable = false
                }
            }
        }
    }

    func modify(ipAdress: String, port: UInt16) {
        self.ipAdress = ipAdress
        self.port = port
    }
    /// 连接对应端口
    func connect() {
        socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: socketQueue)
        do {
            try socket?.bind(toPort: 0)
            try socket?.beginReceiving()
            keepLiveTime = DinDeliver.KeepLiveTimeoutSec
            // 如果ip不存在，或者端口等于0，则不请求心跳
            if ipAdress.count > 0, port > 0 {
                startKeepLive()
            }
        } catch {
        }
    }

    // 处理通道返回的数据
    func checkData(_ msctData: MSCT) {
        // 如果是ping的数据则不检测
        var isPingMSCT = false
        if let optionHeader = msctData.optionHeader?[DinMSCTOptionID.method],
           let data = optionHeader.data,
           String(data: data, encoding: .utf8) == "ping" {
            isPingMSCT = true
        }
        // 过滤自身心跳包的数据
        if msctData.messageID() == keepLiveCommunication?.messageID {
            keepLiveCommunication?.msctReceived(msctData)
        } else if isPingMSCT {
            deliverDelegate?.deliver(self, didReceiveP2PPingData: msctData)
        } else {
            // 正常收发的数据
//            dsLog("socket did received deliver: \(msctData.messageID())")
            deliverDelegate?.deliver(self, didReceiveData: msctData)
        }
    }

    func keepLiveResultReceived(_ communication: DinCommunication) {
        if communication == keepLiveCommunication {
            DinDeliver.keepLiveCommunicationQueue.async(flags: .barrier) { [weak self] in
                self?.unsafeKeepLiveCommunication = nil
            }
        }
    }
}

// MARK: - 外部方法
extension DinDeliver {
    /// 连接到对应的端口
    /// - Parameters:
    ///   - ipAdress: IP地址
    ///   - port: 端口
    @objc func connectToDestination(include ipAdress: String, port: UInt16) {
        // 默认先断开连接
        disconnect()
        // 保存ip、port
        modify(ipAdress: ipAdress, port: port)
        // 连接
        connect()
    }

    /// 停止监听
    public func disconnect() {
        /// 安全操作线程
        DinDeliver.motifyPropertyQueue.async(flags: .barrier) { [weak self] in
            // 清空记录
            self?.unsafeSendMessageIDs.removeAll()
            // 重置属性
            self?.unsafeAvailable = false
            self?.unsafeIsConnected = false
        }
        socket?.pauseReceiving()
        socket?.close()
        socket = nil
        stopKeepLive()
        modify(ipAdress: "", port: 0)
    }

    /// 发送Data数组
    public func sendDatas(_ datas: [Data], messageID: String) {
        sendDatas(datas, messageID: messageID, toHost: ipAdress, port: port)
    }
    public func sendDatas(_ datas: [Data], messageID: String, toHost: String, port: UInt16) {
//        if ipAdress != "mm01.sca.im" && !ipAdress.contains("192") {
//        }
        for data in datas {
            socket?.send(data, toHost: toHost, port: port, withTimeout: -1, tag: 1)
        }
        /// 安全操作线程
        DinDeliver.motifyPropertyQueue.async(flags: .barrier) { [weak self] in
            self?.unsafeSendMessageIDs.append(messageID)
        }
    }

    /// 发送Data数组
    public func sendRawData(_ rawData: Data) {
//        if ipAdress != "mm01.sca.im" {
//        }
        socket?.send(rawData, toHost: ipAdress, port: port, withTimeout: -1, tag: 1)
    }

    func setKeepLiveCommunication(_ comm: DinCommunication?) {
        DinDeliver.keepLiveCommunicationQueue.async(flags: .barrier) { [weak self] in
            self?.unsafeKeepLiveCommunication = comm
            self?.unsafeKeepLiveCommunication?.delegate = self
            self?.unsafeKeepLiveCommunication?.run()
        }
    }
}

// MARK: - 心跳包处理
extension DinDeliver {
    // 开始计时
    func startKeepLive() {
        DinDeliver.keepLiveTimerQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.unsafeKeepLiveTimer = nil
            // 统一在主线程里面新建timer
            self.unsafeKeepLiveTimer = DinGCDTimer(timerInterval: .seconds(self.keepLiveTime), isRepeat: true, executeBlock: { [weak self] in
                self?.keepLive()
            })
            self.keepLive()
        }
    }
    // 停止计时
    private func stopKeepLive() {
        DinDeliver.keepLiveTimerQueue.async(flags: .barrier) { [weak self] in
            self?.unsafeKeepLiveTimer = nil
        }
    }

    /// 发送心跳包
    @objc func keepLive() {
        if let keepLiveComm = deliverDataSource?.deliver(requestKeepliveCommunication: self, withSuccess:{ [weak self] (_) in
            self?.keepLiveSuccess()
        }, fail: { [weak self] (_) in
            self?.keepLiveFail()
        }, timeout: { [weak self] (messageID) in
            self?.keepLiveFail()
        }) {
            // 开始心跳
            setKeepLiveCommunication(keepLiveComm)
        }
    }

//    private func keepLiveComm(success: DinCommunicationCallback.SuccessBlock?,
//                              fail: DinCommunicationCallback.FailureBlock?,
//                              timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication? {
//        guard let `communicationDevice` = communicationDevice else {
//            // 如果device为空，则不适用于设备心跳请求
//            return nil
//        }
//        return DinCommunicationGenerator.communicationDeviceKeepLive(with: communicationIdentity,
//                                                                     destination: communicationDevice,
//                                                                     dataEncryptor: dataEncryptor,
//                                                                     success: success,
//                                                                     fail: fail,
//                                                                     timeout: timeout)
//    }

    /// 设备心跳包收不到回应的时候,记录一下失败次数，如果连接服务器或者设备失败，重新连接一次再不行才报离线
    func keepLiveFail() {
        // 如果不能收到心跳包，同时当前心跳包不是15s一次，心跳包改成15s发一次
        if keepLiveTime !=  DinDeliver.KeepLiveTimeoutSec {
            keepLiveTime = DinDeliver.KeepLiveTimeoutSec
            // 刷新心跳包
            startKeepLive()
        }
        /// 安全操作线程
        DinDeliver.motifyPropertyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }
            self.unsafeAvailable = false
            self.unsafeKeepLiveFailCount += 1
            if self.unsafeKeepLiveFailCount > self.keepLiveFailTotal - 1 {
                self.unsafeKeepLiveFailCount = 2
                self.unsafeIsConnected = false
            }
        }
    }
    /// 只要收到回应,马上清除失败计数,设置通道成功
    func keepLiveSuccess() {
        // 如果能收到心跳包，同时当前心跳包不是50s一次，则心跳包改成50s发一次
        if keepLiveTime !=  DinDeliver.keepLiveReceivedSec {
            keepLiveTime = DinDeliver.keepLiveReceivedSec
            // 刷新心跳包
            startKeepLive()
        }
        /// 安全操作线程
        DinDeliver.motifyPropertyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }
            self.unsafeKeepLiveFailCount = 0
            self.unsafeAvailable = true
            self.unsafeIsConnected = true
        }
    }
}

// MARK: - 心跳包回调
extension DinDeliver: DinCommunicationDelegate {
    func communication(requestSendData datas: [Data], withMessageID messageID: String) {
        sendDatas(datas, messageID: messageID)
    }

    func communication(complete communication: DinCommunication) {
        keepLiveResultReceived(communication)
    }

    func communication(ackTimeout communication: DinCommunication) {
        //
    }

    func communication(_ communication: DinCommunication, requestResendPackages messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType, fileName: String?) {
        guard let `communicationDevice` = communicationDevice else {
            // 如果device为空，则不适用于设备心跳请求
            return
        }
        // 这里只要是利用DinCommunication打包需要的data发送给设备
        let params = DinRequestUDPPackagesParams(withMessageID: messageID,
                                                 source: communicationIdentity,
                                                 destination: communicationDevice,
                                                 indexes: indexes,
                                                 fileName: fileName,
                                                 fileType: fileType)
        guard let comm = DinCommunicationGenerator.requestUDPPackages(params: params,
                                                                     senderArea: communicationDevice.area,
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
        sendDatas(datas, messageID: comm.messageID)
    }
    
    func communication(requestActionResultReceived communication: DinCommunication, isProxy: Bool) {
        guard let `communicationDevice` = communicationDevice else {
            // 如果device为空，则不适用于设备心跳请求
            return
        }
        // 这里只要是利用DinCommunication打包需要的data发送给设备
        guard let comm = DinCommunicationGenerator.actionResultReceived(withMessageID: communication.messageID,
                                                                        isProxy: isProxy,
                                                                        source: communicationIdentity,
                                                                        destination: communicationDevice,
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
        sendDatas(datas, messageID: comm.messageID)
    }
}

// MARK: - 收发回调
extension DinDeliver: GCDAsyncUdpSocketDelegate {
    // 成功连接服务器
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
    }

    // 连接服务器失败
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {
        disconnect()
    }

    // UDP的信息入口
    public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        // 收到的消息【并发队列】
//        if ipAdress != "mm01.sca.im" && !ipAdress.contains("192") {
//        }
        let bytes = data.dataBytes
        if bytes.count > 4, (bytes[0] >> 6) == 0b10 {
            // kcp data 前面32个bit就是conv, conv 头两个是10，就是目标kcp
            // 获取convString
            let kcpConv = KCPObject.conv(of: data)
            DinSupportNotification.notifyProxyDeliverKcpDataReceived(with: data, from: kcpConv)
        } else if (bytes[0] >> 6) == 0b11, let msct = try? MSCT(data: data) {
            // kcp data 前面32个bit就是conv, conv 头两个是10，就是目标kcp
//                dsLog("socket did received check: \(String(decoding: data, as: UTF8.self))")
//                dsLog("ip: \(self.ipAdress) port: \(self.port) - \(self) - keepLiveComm receivedata - ava:\(self.available) - isconn:\(self.isConnected)")
            checkData(msct)
        } else {
            // 判断是不是返回的p2p地址
            let dataString = String(decoding: data, as: UTF8.self)
            let addrArr = dataString.components(separatedBy: ":")
            if addrArr.count == 2, let p2pPort = UInt16(addrArr[1]) {
                deliverDelegate?.deliver(self, didReceiveP2PAddress: addrArr[0], p2pPort: p2pPort)
            }
        }
    }
}
