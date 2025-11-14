//
//  DinSupportQueueName.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

public class DinSupportQueueName: NSObject {
    /// GCD计时器所用的timer
    public static let gcdTimerQueue = "com.dinsafer.dinsupport.queue.gcdTimer"
    /// DSMSCTHandler会在接收到第一个msct包的时候，按照messageID新建对应的处理线程，以下线程就是保证这个线程不会并发新建
    static let communicationHandlerQueueInit = "com.dinsafer.dinsupport.queue.HandlerQueueInit"
    /// DSMSCTHandler用于接收msct包合并的时候的安全线程【只是前缀】
    static let communicationHandler = "com.dinsafer.dinsupport.queue.Handler"
    /// DSCommunicationRecorder进行对 App的UDP通信的Communication对象 记录所用到的线程
    static let recordsQueue = "com.dinsafer.dinsupport.queue.communication.record"
    /// DSCommunicator进行对 App的UDP通信的Communication对象的数据 处理所用到的线程
    static let communicatorQueue = "com.dinsafer.dinsupport.queue.communicator"
    /// App的Deliver并行记录通讯包ID、属性的线程
    static let deliverMotifyProperty = "com.dinsafer.dinsupport.queue.deliverMotifyProperty"
    /// DSDeliver用于收发心跳包的安全线程
    static let keepLiveCommunication = "com.dinsafer.dinsupport.queue.keepLiveCommunication"
    /// DSDeliver用于收发心跳包的安全线程
    static let keepLiveTimer = "com.dinsafer.dinsupport.queue.keepLiveTimer"
    /// App的检测网络连通性的线程
    static let reachability = "com.dinsafer.dinsupport.queue.reachability"
    /// 对MSCT通讯的对象相关状态进行修改的安全线程
    static let msctDeviceStatus = "com.dinsafer.dinsupport.queue.msctDeviceStatus"
    /// App的UDPp2p通信用到的并行收发线程【只是前缀】
    static let deviceP2pDeliver = "com.dinsafer.dinsupport.queue.P2pDeliver"
    /// App的UDPp2p通信打洞期间安全线程
    static let deviceP2pComm = "com.dinsafer.dinsupport.queue.P2PConnection"
    /// App的UDP局域网通信用到的并行收发线程【只是前缀】
    static let deviceLanDeliver = "com.dinsafer.dinsupport.queue.LanDeliver"
    /// DinLog 打印日志时使用的 OSLog 对象的缓存读取线程
    static let log = "com.dinsafer.dinsupport.queue.log"
}
