//
//  DinDeviceControl.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

/// 设备的连接状态
public enum DinDeviceControlNetworkState {
    // 还没有检测
    case unknown
    // 连接中
    case connecting
    // 在线
    case online
    // 离线
    case offline
}

open class DinDeviceControl: NSObject {
    // 用于通过代理模式（服务器转发）发送MSCT的Delivery
    private(set) var proxyDeliver: DinProxyDeliver
    // 要连接的设备
    public private(set) var communicationDevice: DinCommunicationDevice
    // 连接设备的凭证（自己）
    public private(set) var communicationIdentity: DinCommunicationIdentity
    /// 数据的加解密工具
    public let dataEncryptor: DinCommunicationEncryptor

    public private(set) var communicator: DinCommunicator?
    public private(set) var delivery: DinDeviceUDPDelivery?

    /// 是否需要维持心跳包，默认需要。【如果不需要心跳包】设备默认在线
    public private(set) var needKeepLive: Bool

    /// 标记设备的网络状态
    public var networkState: DinDeviceControlNetworkState {
        get {
            return DinDeviceUDPDelivery.queue.sync { [weak self] in
                return self?.unsafeNetworkState ?? .unknown
            }
        }
        set {
            DinDeviceUDPDelivery.queue.async(flags: .barrier) { [weak self] in
                self?.unsafeNetworkState = newValue
            }
        }
    }
    /// 标记设备的状态【不安全状态】
    private var unsafeNetworkState: DinDeviceControlNetworkState = .unknown {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                DinSupportNotification.postNetworkState(with: self.communicationDevice, networkState: self.networkState)
            }
        }
    }

    /// 根据要通信的设备生成通讯控制器
    /// - Parameters:
    ///   - proxyDelivery: 用于通过代理模式（服务器转发）发送MSCT的Delivery
    ///   - communicationDevice: 要连接的设备
    ///   - communicationIdentity: 连接设备的凭证（自己）
    ///   - dataEncryptor: 数据的加解密工具
    ///   - needKeepLive: 是否需要心跳
    ///   - useLanAndP2P: 是否需要局域网和P2P通讯
    public init(with proxyDeliver: DinProxyDeliver,
                communicationDevice: DinCommunicationDevice,
                communicationIdentity: DinCommunicationIdentity,
                dataEncryptor: DinCommunicationEncryptor,
                needKeepLive: Bool = true,
                useLanAndP2P: Bool = false) {
        self.proxyDeliver = proxyDeliver
        self.communicationDevice = communicationDevice
        self.communicationIdentity = communicationIdentity
        self.dataEncryptor = dataEncryptor
        self.needKeepLive = needKeepLive
        super.init()
        self.communicator = DinCommunicator(with: self)
        self.delivery = DinDeviceUDPDelivery(with: self, useLanAndP2P: useLanAndP2P)
        self.delivery?.deliveryDataSource = self
    }

    public func sendRawData(withDeliverType type: DinDeviceUDPDeliverType, rawData: Data) {
        // 当引入了全局的代理通道DSCore.proxyDelivery之后, 就算isOnline = false, 也可以通过全局的方式发送命令并且收到
        // 所以这里做个限制，如果使用者没有调用连接方法来连接主机的话，不能发送命令
        guard networkState == .online else {
            return
        }
        delivery?.sendRawDataWithDeliver(type: type, rawData: rawData)
    }


    // MARK: - 信息的收发
    /// 按照优先级返回可用的通道类型
    /// 优先级是 lanDeliver > upnpDeliver > proxyDeliver
    /// - Returns: 通道类型
    public func availableDeliverByPriority() -> DinDeviceUDPDeliverType {
        delivery?.availableDeliverByPriority() ?? .proxy
    }

    // MARK: - 数据沟通相关方法
    /// 供communicator使用的发送数据通道
    func sendDatas(_ datas: [Data], belongsTo messageID: String) {
        // 当引入了全局的代理通道DSCore.proxyDelivery之后, 就算isOnline = false, 也可以通过全局的方式发送命令并且收到
        // 所以这里做个限制，如果使用者没有调用连接方法来连接主机的话，不能发送命令
        guard networkState == .online else {
            return
        }
        delivery?.sendDatasWithDelivers(datas, belongsTo: messageID)
    }

    /// 供udpDeliver在接收到操作回复之后通知control处理数据包
    /// - Parameter msctData: 操作回复数据包
    func msctDataReceived(_ msctData: MSCT) {
        DispatchQueue.main.async { [weak self] in
            // 提供给Communicator，进而提供给Communication进行数据处理，这里是子线程回复的，所以转成主线程进行串行处理
            self?.communicator?.dataReceived(msctData)
        }
    }

    // MARK: - 第三方数据通知
    open func receiveOtherCommunicationResult(_ result: DinMSCTResult) {
    }

    // MARK: - 不同通道都有不同的心跳实现
    open func requestKeepliveCommunication(deliverType: DinDeviceUDPDeliverType, withSuccess success: DinCommunicationCallback.SuccessBlock?, fail: DinCommunicationCallback.FailureBlock?, timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication? {
        return DinCommunicationGenerator.communicationDeviceKeepLive(with: communicationIdentity,
                                                                     destination: communicationDevice,
                                                                     dataEncryptor: dataEncryptor,
                                                                     success: success,
                                                                     fail: fail,
                                                                     timeout: timeout)
    }

    /// 重新刷新Lan通道
    open func refreshLanPipe(ipAdress: String? = nil, port: UInt16? = nil) {
        delivery?.reconnectLan(ipAdress: ipAdress, port: port)
    }
    /// 重新刷新P2p通道, 如果本来就是p2p连接上了，就先不管了
    open func refreshP2pPipeIfNeeded() {
        delivery?.reconnectP2p(forceReconnect: false)
    }
}

// MARK: - DinDeviceUDPDeliveryDataSource
extension DinDeviceControl: DinDeviceUDPDeliveryDataSource {
    public func delivery(requestKeepliveCommunication delivery: DinDeviceUDPDelivery, deliverType: DinDeviceUDPDeliverType, withSuccess success: DinCommunicationCallback.SuccessBlock?, fail: DinCommunicationCallback.FailureBlock?, timeout: DinCommunicationCallback.TimeoutBlock?) -> DinCommunication? {
        requestKeepliveCommunication(deliverType: deliverType,
                                     withSuccess: success,
                                     fail: fail,
                                     timeout: timeout)
    }
}

// MARK: - 对外方法
extension DinDeviceControl {
    /// 连接设备 [请确保IPC保有UniqueID、Token、area信息]
    /// - Parameter complete: 完成回调，是否成功
    @objc open func connect(complete: ((Bool) -> Void)?) {
        delivery?.connect(complete: complete)
    }

    /// 断开连接设备
    @objc open func disconnect() {
        communicator?.emptyCommunicationRecords()
        delivery?.disconnect()
    }
}
