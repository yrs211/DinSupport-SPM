//
//  DinDeviceUDPDelivery.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

/// 沟通器Type
public enum DinDeviceUDPDeliverType {
    case lan
    case p2p
    case proxy
}

public protocol DinDeviceUDPDeliveryDataSource: NSObjectProtocol {
    /// 沟通器请求心跳逻辑
    /// 请根据给出的成功、失败、超时回调，新建一个DinCommunication实例传入沟通器
    /// - Parameters:
    ///   - delivery: 沟通器
    ///   - deliveryType: 沟通器Type
    ///   - success: 成功回调（用于新建DinCommunication实例）
    ///   - fail: 失败回调（用于新建DinCommunication实例）
    ///   - timeout: 超时回调（用于新建DinCommunication实例）
    func delivery(requestKeepliveCommunication delivery: DinDeviceUDPDelivery,
                  deliverType: DinDeviceUDPDeliverType,
                  withSuccess success: DinCommunicationCallback.SuccessBlock?,
                  fail: DinCommunicationCallback.FailureBlock?,
                  timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication?
}

open class DinDeviceUDPDelivery: NSObject {
    /// 数据请求
    weak var deliveryDataSource: DinDeviceUDPDeliveryDataSource?
    // 用于标记的设备模型
    private weak var deviceControl: DinDeviceControl?
    /// 数据的加解密工具
    let dataEncryptor: DinCommunicationEncryptor
    /// 用于生成Communication
    private(set) var communicationDevice: DinCommunicationDevice
    /// 用于生成Communication的凭证
    private(set) var communicationIdentity: DinCommunicationIdentity
    /// 数据的读写队列
    static let queue = DispatchQueue(label: DinSupportQueueName.msctDeviceStatus, attributes: .concurrent)
    /// keepliveQueue, 处理一下keeplive的多线程并发
    /// 这里原来是用 DinDeliver.keepLiveCommunicationQueue 来控制的，但是由于是 静态变量，如果在里面添加了p2p的线程操作，这个全局静态线程会一直持有，导致Delivery不能释放
    /// 所以这里改用类属性赋值
    let keepLiveCommunicationQueue: DispatchQueue
    /// 记录数组【不能直接使用，需要搭配queue来读写以达到线程安全】
    private var unsafeProxyConnected = false {
        didSet {
            checkIfDeviceNetworkState()
        }
    }
    /// 是否连接成功（心跳包决定的）
    private var isProxyConnected: Bool {
        var copyProxyConnected = false
        DinDeviceUDPDelivery.queue.sync { [weak self] in
            if let self = self {
                copyProxyConnected = self.unsafeProxyConnected
            }
        }
        return copyProxyConnected
    }

    /// 心跳包时间，收到心跳包50s，心跳包超时15s
    static private let keepLiveReceivedSec: TimeInterval = 50
    static private let KeepLiveTimeoutSec: TimeInterval = 15
    private var keepLiveTime: TimeInterval = DinDeviceUDPDelivery.KeepLiveTimeoutSec
    // 心跳包失败次数超过规定时，重连失败再弹离线
    private var keepLiveFailCount: Int = 0
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
    /// 记录keeplive的Communication【不能直接使用，需要搭配keepLiveCommunicationQueue来读写以达到线程安全】
    private var unsafeKeepLiveCommunication: DinCommunication?
    // 发送心跳包使用的通信对象
    private var proxyKeepLiveCommunication: DinCommunication? {
        var copyComm: DinCommunication?
        keepLiveCommunicationQueue.sync { [weak self] in
            if let self = self {
                copyComm = self.unsafeKeepLiveCommunication
            }
        }
        return copyComm
    }
    /// 记录发送P2P连接通知的Communication【不能直接使用，需要搭配keepLiveCommunicationQueue来读写以达到线程安全】
    private var unsafeCallP2PCommunication: DinCommunication?
    // 发送心跳包使用的通信对象
    private var callP2PCommunication: DinCommunication? {
        var copyComm: DinCommunication?
        keepLiveCommunicationQueue.sync { [weak self] in
            if let self = self {
                copyComm = self.unsafeCallP2PCommunication
            }
        }
        return copyComm
    }


    /// 是否连接（否的话，所有刷新通道操作都会停止，例如手机网络更变的自动刷新）
    /// 这个状态是标注连接器正处于不断请求或者保持连接状态（是和否由control定义），不是当前网络状态
    private var deviceConnected: Bool = false
    private var connectCompleteBlock: ((Bool) -> Void)?

    /// p2p模式通道
    var p2pDeliver: DinP2PDeliver?
    /// p2p打洞工具
    var p2pDiscover: DinP2PDiscover?
    /// 打洞失败计数器
    var tryP2Pcount: Int = 0
    let p2pFailCount: Int = 5
    /// 自己通讯的P2P地址（包含端口）
    var selfP2PAddress: String = ""
    /// 自己通讯的局域网地址端口
    var selfP2PPort: UInt16 = 0
    /// 对端通讯的P2P地址（包含端口）
    var targetP2PAddress: String = ""
    /// 对端通讯的局域网地址端口
    var targetP2PPort: UInt16 = 0

    /// 局域网通道
    var lanDeliver: DinDeliver?

    /// 是否需要局域网和p2p通讯
    let useLanAndP2P: Bool

    deinit {
        // 确保关闭计时器
        unsafeKeepLiveTimer = nil
        unsafeKeepLiveCommunication = nil
        unsafeCallP2PCommunication = nil
        NotificationCenter.default.removeObserver(self)
    }

    init(with deviceControl: DinDeviceControl, useLanAndP2P: Bool) {
        self.useLanAndP2P = useLanAndP2P
        self.deviceControl = deviceControl
        self.communicationDevice = deviceControl.communicationDevice
        self.communicationIdentity = deviceControl.communicationIdentity
        self.dataEncryptor = deviceControl.dataEncryptor
        self.keepLiveCommunicationQueue = DispatchQueue(label: "\(DinSupportQueueName.keepLiveCommunication)_\(deviceControl.communicationDevice.deviceID)",
                                                        attributes: .concurrent)

        if (self.useLanAndP2P) {
            // p2p通道
            let p2pQueueName = DinSupportQueueName.deviceP2pDeliver + self.communicationDevice.deviceID
            p2pDeliver = DinP2PDeliver(with: DispatchQueue(label: p2pQueueName, attributes: .concurrent),
                                    dataEncryptor: dataEncryptor,
                                    belongsTo: self.communicationDevice,
                                    from: communicationIdentity)

            if let p2pDeliver = p2pDeliver {
                // P2P工具
                // messageID在工具内部提供
                let p2pParams = DinOperateTaskParams(with: self.dataEncryptor,
                                                     source: self.communicationIdentity,
                                                     destination: self.communicationDevice,
                                                     messageID: "",
                                                     sendInfo: nil,
                                                     ignoreSendInfoInNil: false)
                p2pDiscover = DinP2PDiscover(withP2PDeliver: p2pDeliver, dataEncryptor: self.dataEncryptor, connectTargetParams: p2pParams)
            }

            // 局域网通道
            let lanQueueName = DinSupportQueueName.deviceLanDeliver + self.communicationDevice.deviceID
            lanDeliver = DinDeliver(with: DispatchQueue(label: lanQueueName, attributes: .concurrent),
                                    dataEncryptor: dataEncryptor,
                                    belongsTo: self.communicationDevice,
                                    from: communicationIdentity)
        }

        super.init()
        p2pDeliver?.deliverDelegate = self
        lanDeliver?.deliverDelegate = self
        p2pDeliver?.deliverDataSource = self
        lanDeliver?.deliverDataSource = self
        // 网络更变
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(networkDidChanged),
                                               name: .reachabilityChanged,
                                               object: nil)
        // 检查是否有host更变
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(checkDeliverHost(_:)),
                                               name: .dinDeviceDeliverHostCheck,
                                               object: nil)
        // 系统的UDP代理模式通道收到的MSCT包
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(receivedProxyDeliverData(_:)),
                                               name: .dinProxyDeliverDataReceived,
                                               object: nil)
    }

    // MARK: - 其他
    // 网络改变处理, 由于自身网络的变化会导致原本soket的链接不上，所以这里需要重新链接socket
    @objc private func networkDidChanged() {
        guard deviceConnected else {
            return
        }
        // 重启
        DinDeviceUDPDelivery.queue.async(flags: .barrier) { [weak self] in
            self?.unsafeProxyConnected = false
        }
        startKeepLive()
        reconnectLan()
        reconnectP2p()
    }

    // 检查通道是否有更改
    @objc private func checkDeliverHost(_ notif: Notification) {
        guard deviceConnected,
            let msctID = notif.userInfo?[DinSupportNotificationKey.dinMSCTIDKey] as? String,
            msctID == communicationDevice.uniqueID else {
            return
        }
        // 检查p2p、lan的连接, 如果有不相同的地方，更新连接
        reconnectP2p()
        reconnectLan()
    }

    /// 直接重新连接lan
    func reconnectLan(ipAdress: String? = nil, port: UInt16? = nil) {
        guard useLanAndP2P else {
            return
        }

        // 如果有传入指定的地址，端口，先检查有没有相同
        if let lanIP = ipAdress, let lanPort = port {
            // 如果不相同，则修改局域网
            if (lanIP != communicationDevice.lanAddress) || (lanPort != communicationDevice.lanPort) {
                communicationDevice.lanAddress = lanIP
                communicationDevice.lanPort = lanPort
            } else if lanDeliver?.available ?? false {
                // 如果相同而且lan通道是通的不处理, 不重连
                return
            }
        }

        // 重新连接Lan
        lanDeliver?.connectToDestination(include: communicationDevice.lanAddress, port: communicationDevice.lanPort)
    }
    /// 开始p2p打洞流程
    /// - Parameter withoutRequest: 是否要请求服务器获取p2p地址
    /// - Parameter forceReconnect: 无论p2p是否connected，强制重连
    func reconnectP2p(withoutRequest: Bool = false, forceReconnect: Bool = true) {
        guard useLanAndP2P else {
            return
        }
        // 如果不是强制重连，然后p2p已经连上了，就不理了
        if !forceReconnect, p2pDeliver?.isConnected ?? false {
            return
        }
        // p2p
        if !withoutRequest {
            // 如果需要请求服务器获取p2p地址，重置p2p sockect
            p2pDeliver?.disconnect()
            selfP2PAddress = ""
            selfP2PPort = 0
            targetP2PAddress = ""
            targetP2PPort = 0
        }
        p2pDeliver?.connectToDestination(include: targetP2PAddress, port: targetP2PPort)

        // !DinSupport.getPublicIPHost.isEmpty 和 DinSupport.getPublicIPPort > 0 是请求客户端的公网IPC和端口的必备条件
        // 如果两者缺一或者都没有，通过上面重置，恢复到该有的状态之后不再继续P2P打洞逻辑，所以判断写在了这里
        if !withoutRequest, !DinSupport.getPublicIPHost.isEmpty, DinSupport.getPublicIPPort > 0 {
            // 重置失败次数
            tryP2Pcount = 0
            // 向服务器获取自己P2P地址
            p2pDeliver?.sendDatas([DinP2PDiscover.genGetSelfP2PAddressRequestData()],
                                 messageID: "requestP2PAddr",
                                 toHost: DinSupport.getPublicIPHost,
                                 port: DinSupport.getPublicIPPort)
        }
    }

    func connect(complete: ((Bool) -> Void)?) {
        // control请求连接，该属性正处于 不断请求或者保持连接状态
        deviceConnected = true

        guard deviceControl?.networkState != .online else {
            // 如果本身就是连接状态，直接返回成功
            complete?(true)
            return
        }
        // 通知上层正在连接
        deviceControl?.networkState = .connecting
        connectCompleteBlock = complete
        // 重置失败时间
        keepLiveFailCount = 0
        keepLiveTime = DinDeviceUDPDelivery.KeepLiveTimeoutSec
        // 打开三个通道
        startKeepLive()
        reconnectLan()
        reconnectP2p()
    }
    private func completed(_ success: Bool) {
        // 通知设备管理器，设备离线
        deviceControl?.networkState = success ? .online : .offline
        // 回调
        connectCompleteBlock?(success)
        connectCompleteBlock = nil
    }

    func disconnect() {
        // 三个通道都关闭
        stopKeepLive()
        // 强制断开
        keepLiveFailCount = 3
        DinDeviceUDPDelivery.queue.async(flags: .barrier) { [weak self] in
            self?.unsafeProxyConnected = false
        }
        // 断开另外两个通道
        lanDeliver?.disconnect()
        p2pDeliver?.disconnect()
        // control请求断开连接，该属性正处于 关闭连接状态，不需要继续心跳包
        deviceConnected = false
        deviceControl?.networkState = .offline
    }

    // MARK: - 信息的收发
    /// 按照优先级返回可用的通道类型
    /// 优先级是 lanDeliver > upnpDeliver > proxyDeliver
    /// - Returns: 通道类型
    func availableDeliverByPriority() -> DinDeviceUDPDeliverType {
        if lanDeliver?.available ?? false {
            return .lan
        } else if p2pDeliver?.available ?? false {
            return .p2p
        } else {
            return .proxy
        }
    }

    // 按照顺序使用对应接口
    func sendDatasWithDelivers(_ datas: [Data], belongsTo messageID: String, forceProxy: Bool = false) {
        let type = availableDeliverByPriority()
        var deliver: DinDeliver?
        switch type {
        case .lan:
            deliver = lanDeliver
        case .p2p:
            deliver = p2pDeliver
        default:
            deliver = deviceControl?.proxyDeliver
//            dsLog("\(messageID) send by deliver: proxy")
        }
        // 发送Data, 这里需要记录messageID是为了任务一旦超时，会通知到对应发送通道关闭
        deliver?.sendDatas(datas, messageID: messageID)
    }

    /// 使用对应的通道发送对应的裸数据
    func sendRawDataWithDeliver(type: DinDeviceUDPDeliverType, rawData: Data) {
        switch type {
        case .lan:
            if lanDeliver?.available ?? false {
                lanDeliver?.sendRawData(rawData)
            }
        case .p2p:
            if p2pDeliver?.available ?? false {
                p2pDeliver?.sendRawData(rawData)
            }
        default:
            // proxy
            deviceControl?.proxyDeliver.sendRawData(rawData)
        }
    }

    // 系统的UDP代理模式通道收到的MSCT包
    @objc private func receivedProxyDeliverData(_ notif: Notification) {
        guard let msctData = notif.userInfo?[DinSupportNotificationKey.dinMSCTDataKey] as? MSCT else {
            return
        }
        // 检查是否是属于本设备的消息
        let senderUniqueID = notif.userInfo?[DinSupportNotificationKey.dinMSCTIDKey] as? String ?? ""
        guard senderUniqueID == communicationDevice.uniqueID else {
            return
        }
        // 过滤自身心跳包的数据
        if msctData.messageID() == proxyKeepLiveCommunication?.messageID {
            proxyKeepLiveCommunication?.msctReceived(msctData)
        } else if msctData.messageID() == callP2PCommunication?.messageID {
            keepLiveCommunicationQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                self.unsafeCallP2PCommunication?.msctReceived(msctData)
            }
        } else {
            // 正常收发的数据
            deviceControl?.msctDataReceived(msctData)
        }
    }
}

// MARK: - 心跳包处理
extension DinDeviceUDPDelivery {
    // 开始计时
    private func startKeepLive() {
        guard deviceControl?.needKeepLive ?? false else {
            deviceControl?.networkState = .online
            completed(true)
            return
        }
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
    func keepLive() {
        if let proxyKeepLiveComm = deliveryDataSource?.delivery(requestKeepliveCommunication: self, deliverType: .proxy, withSuccess: { [weak self] (_) in
            self?.keepLiveSuccess()
        }, fail: { [weak self] (_) in
            self?.keepLiveFail()
        }, timeout: { [weak self] (messageid) in
            self?.keepLiveFail()
        }) {
            keepLiveCommunicationQueue.async(flags: .barrier) { [weak self] in
                self?.unsafeKeepLiveCommunication = proxyKeepLiveComm
                self?.unsafeKeepLiveCommunication?.delegate = self
                self?.unsafeKeepLiveCommunication?.run()
            }
        }
    }

//    private func keepLiveComm(success: DinCommunicationCallback.SuccessBlock?,
//                              fail: DinCommunicationCallback.FailureBlock?,
//                              timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication? {
//        return DinCommunicationGenerator.communicationDeviceKeepLive(with: communicationIdentity,
//                                                                     destination: communicationDevice,
//                                                                     dataEncryptor: dataEncryptor,
//                                                                     success: success,
//                                                                     fail: fail,
//                                                                     timeout: timeout)
//    }

    func keepLiveResultReceived(_ communication: DinCommunication) {
        if communication == proxyKeepLiveCommunication {
            keepLiveCommunicationQueue.async(flags: .barrier) { [weak self] in
                self?.unsafeKeepLiveCommunication = nil
            }
        }
    }

    /// 设备心跳包收不到回应的时候,记录一下失败次数，如果连接服务器或者设备失败，重新连接一次再不行才报离线
    func keepLiveFail() {
        // 如果不能收到心跳包，同时当前心跳包不是15s一次，心跳包改成15s发一次
        if keepLiveTime !=  DinDeviceUDPDelivery.KeepLiveTimeoutSec {
            keepLiveTime = DinDeviceUDPDelivery.KeepLiveTimeoutSec
            // 刷新心跳包
            startKeepLive()
        }
        keepLiveFailCount += 1
        if keepLiveFailCount > keepLiveFailTotal - 1 {
            keepLiveFailCount = 3
            DinDeviceUDPDelivery.queue.async(flags: .barrier) { [weak self] in
                self?.unsafeProxyConnected = false
            }
        }
    }
    /// 只要收到回应,马上清除失败计数,设置通道成功
    func keepLiveSuccess() {
        // 如果能收到心跳包，同时当前心跳包不是50s一次，则心跳包改成50s发一次
        if keepLiveTime !=  DinDeviceUDPDelivery.keepLiveReceivedSec {
            keepLiveTime = DinDeviceUDPDelivery.keepLiveReceivedSec
            // 刷新心跳包
            startKeepLive()
        }
        keepLiveFailCount = 0
        DinDeviceUDPDelivery.queue.async(flags: .barrier) { [weak self] in
            self?.unsafeProxyConnected = true
        }
    }
}

// MARK: - 心跳包回调
extension DinDeviceUDPDelivery: DinCommunicationDelegate {
    func communication(requestSendData datas: [Data], withMessageID messageID: String) {
        deviceControl?.proxyDeliver.sendDatas(datas, messageID: messageID)
    }

    func communication(complete communication: DinCommunication) {
        keepLiveResultReceived(communication)
    }

    func communication(ackTimeout communication: DinCommunication) {
        //
    }

    func communication(_ communication: DinCommunication, requestResendPackages messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType, fileName: String?) {
        let params = DinRequestUDPPackagesParams(withMessageID: messageID,
                                                 source: communicationIdentity,
                                                 destination: communicationDevice,
                                                 indexes: indexes,
                                                 fileName: fileName,
                                                 fileType: fileType)
        // 这里只要是利用DinCommunication打包需要的data发送给设备
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
        deviceControl?.proxyDeliver.sendDatas(datas, messageID: comm.messageID)
    }

    func communication(requestActionResultReceived communication: DinCommunication, isProxy: Bool) {
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
        deviceControl?.proxyDeliver.sendDatas(datas, messageID: comm.messageID)
    }

}

// MARK: - deliver 代理方法
extension DinDeviceUDPDelivery: DinDeliverDataSource {
    func deliver(requestKeepliveCommunication deliver: DinDeliver, withSuccess success: DinCommunicationCallback.SuccessBlock?, fail: DinCommunicationCallback.FailureBlock?, timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication? {
        deliveryDataSource?.delivery(requestKeepliveCommunication: self,
                                     deliverType: (deliver == p2pDeliver) ? .p2p : .lan,
                                     withSuccess: success,
                                     fail: fail,
                                     timeout: timeout)
    }
}

extension DinDeviceUDPDelivery: DinDeliverDelegate {
    func deliver(_ deliver: DinDeliver, didReceiveData msctData: MSCT) {
//        if deliver == p2pDeliver {
//            dsLog("\(msctData.messageID()) receive by deliver: upnp")
//        } else if deliver == lanDeliver {
//            dsLog("\(msctData.messageID()) receive by deliver: lan")
//        }
        deviceControl?.msctDataReceived(msctData)
    }

    func deliver(_ deliver: DinDeliver, didReceiveP2PPingData msctData: MSCT) {
        // ping的数据交给P2PDiscover
        p2pDiscover?.receivePing(data: msctData)
    }

    func deliver(_ deliver: DinDeliver, didReceiveP2PAddress p2pAddress: String, p2pPort: UInt16) {
        selfP2PAddress = p2pAddress
        selfP2PPort = p2pPort
        keepLiveCommunicationQueue.async(flags: .barrier) { [weak self] in
            self?.startGetPublicIP()
        }
    }

    private func startGetPublicIP() {
        guard tryP2Pcount < p2pFailCount else { return }
        tryP2Pcount += 1
        let callback = DinCommunicationCallback(successBlock: { [weak self] result in
            guard let self = self else { return }
            // success
            if let targetAddrString = result.payloadDict["kcp_ipv4"] as? String,
                let handShakeID = result.payloadDict["connect_id"] as? UInt32 {
                let addrArr = targetAddrString.components(separatedBy: ":")
                if addrArr.count == 2, let p2pPort = UInt16(addrArr[1]) {
                    self.targetP2PAddress = addrArr[0]
                    self.targetP2PPort = p2pPort
                    // 开始打洞尝试
                    self.p2pDiscover?.beginP2PConnect(targetIP: addrArr[0], targetPort: p2pPort, handShakeID: handShakeID, complete: { [weak self] success in
                        if success {
                            self?.reconnectP2p(withoutRequest: true)
                        }
                    })
                    return
                }
            }
            self.keepLiveCommunicationQueue.asyncAfter(deadline: .now() + 2, flags: .barrier) { [weak self] in
                self?.startGetPublicIP()
            }
        }, failureBlock: { _ in
        }, timeoutBlock: { [weak self] _ in
            self?.keepLiveCommunicationQueue.async(flags: .barrier) { [weak self] in
                self?.startGetPublicIP()
            }
        })

        // 添加新的任务ID
        let p2pParams = DinOperateTaskParams(with: self.dataEncryptor,
                                             source: self.communicationIdentity,
                                             destination: self.communicationDevice,
                                             messageID: String.UUID(),
                                             sendInfo: nil,
                                             ignoreSendInfoInNil: false)

        if let comm = DinCommunicationGenerator.callDestinationP2P(p2pParams,
                                                                   targetP2PAddress: "\(self.selfP2PAddress):\(self.selfP2PPort)",
                                                                   targetID: p2pParams.destination.uniqueID,
                                                                   ackCallback: callback,
                                                                   entryCommunicator: nil) {
            self.unsafeCallP2PCommunication = comm
            self.unsafeCallP2PCommunication?.delegate = self
            self.unsafeCallP2PCommunication?.run()
        }
    }

    func deliverAvailable(_ deliver: DinDeliver) {
        //
    }

    func deliverUnavailable(_ deliver: DinDeliver) {
        //
    }

    func deliverConnected(_ deliver: DinDeliver) {
        guard deviceControl?.needKeepLive ?? false else {
            return
        }
        checkIfDeviceNetworkState()
    }

    func deliverLost(_ deliver: DinDeliver) {
        // 如果是未知或者连接中的状态，则必定是proxy通道的检测，此时p2p和lan的状态都是false的，这个时候不需要提示主机离线
        guard (deviceControl?.needKeepLive ?? false) && deviceControl?.networkState != .unknown && deviceControl?.networkState != .connecting else {
            return
        }
        checkIfDeviceNetworkState()
    }

    private func checkIfDeviceNetworkState() {
        DispatchQueue.main.async { [weak self] in
            var isOnline = false
            // 如果三个通道都lost，报离线
            if !(self?.isProxyConnected ?? false) && !(self?.p2pDeliver?.isConnected ?? false) && !(self?.lanDeliver?.isConnected ?? false) {
                // 当三个通道都连接不上，就报离线
                isOnline = false
            } else {
                // 其中有一个通道能连接，则报在线
                isOnline = true
            }
            // 如果状态相同就停止上报
            if isOnline && self?.deviceControl?.networkState != DinDeviceControlNetworkState.online {
                self?.completed(isOnline)
            } else if !isOnline && self?.deviceControl?.networkState != DinDeviceControlNetworkState.offline {
                self?.completed(isOnline)
            }
        }
    }
}
