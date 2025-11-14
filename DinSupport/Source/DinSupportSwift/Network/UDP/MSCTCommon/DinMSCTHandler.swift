//
//  DinMSCTHandler.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

protocol DinMSCTHandlerDelegate: NSObjectProtocol {
    /// 收到的包处理结果
    ///
    /// - Parameter result: 处理结果
    func completePackage(_ result: DinMSCTResult)

    /// msct包的接收进度
    /// - Parameter percentage: Double类型
    func package(percentageOfCompletion percentage: Double)

    /// 数据包确实，请求重发
    /// - Parameters:
    ///   - messageID: 数据包对应的messageID
    ///   - indexes: 缺失的数据包index
    ///   - fileType: 缺失数据包的数据类型
    func requestResendPackages(with messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType)
}

class DinMSCTHandler: NSObject {
    weak var delegate: DinMSCTHandlerDelegate?
    /// 数据的加解密工具
    private var dataEncryptor: DinCommunicationEncryptor

    /// 用于保护下面queue属性的新建时候，不同线程新建的数据竞争
    static let saveInitQueue = DispatchQueue(label: DinSupportQueueName.communicationHandlerQueueInit, attributes: .concurrent)

    var unsafeQueue: DispatchQueue?
    var queue: DispatchQueue? {
        get {
            // 通过同步的线程获取数值
            var returnQueue: DispatchQueue?
            DinMSCTHandler.saveInitQueue.sync { [weak self] in
                if let self = self {
                    returnQueue = self.unsafeQueue
                }
            }
            return returnQueue
          }
          set {
            // 通过同步的线程设置数值数值
            DinMSCTHandler.saveInitQueue.async(flags: .barrier) { [weak self] in
                if let self = self {
                    self.unsafeQueue = newValue
                }
            }
          }
    }
    /// 数据合并数组【不能直接使用，需要搭配queue来读写以达到线程安全】
    private var unsafeMSCTPacks = [String: DinMSCTPackage]()
    private var msctPacks: [String: DinMSCTPackage] {
        var copyPacks = [String: DinMSCTPackage]()
        queue?.sync { [weak self] in
            if let self = self {
                copyPacks = self.unsafeMSCTPacks
            }
        }
        return copyPacks
    }

    /// 并包的时候Ack包超时时间
    private var combinePackAckTimeout: TimeInterval
    /// 并包的时候Result包超时时间
    private var combinePackResultTimeout: TimeInterval

    init(with dataEncryptor: DinCommunicationEncryptor, combineAckPackTimeout ackTimeout: TimeInterval, resultTimeout: TimeInterval) {
        self.dataEncryptor = dataEncryptor
        self.combinePackAckTimeout = ackTimeout
        self.combinePackResultTimeout = resultTimeout
        super.init()
    }

    /// 获取msct处理
    ///
    /// - Parameter msct: msct
    public func receiveMSCT(_ msct: MSCT) {
        let messageID = msct.messageID()
        if queue == nil {
            let queueName = DinSupportQueueName.communicationHandler + messageID
            queue = DispatchQueue(label: queueName, attributes: .concurrent)
        }
        var packTimeout = combinePackResultTimeout
        if msct.header.msgType == .ACK {
            packTimeout = combinePackAckTimeout
        }
        // 搜索队列里面是否有对应的包
        if messageID.count > 0, let pack = msctPacks[packID(withMSCTType: msct.header.msgType, messageID: messageID)] {
            // 如果找到对应的包，则进行并包处理
            pack.append(msct: msct)
//            dsLog("MSCTHandler insert pack - \(messageID) at msctPacks \n\(msctPacks)")
        } else if let pack = DinMSCTPackage(withMSCT: msct, dataEncryptor: dataEncryptor, timeout: packTimeout) {
            queue?.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    return
                }
                // 如果找不到对应的包，则新建包插入队列
                pack.delegate = self
                self.unsafeMSCTPacks[self.packID(withMSCTType: msct.header.msgType, messageID: messageID)] = pack
//                dsLog("MSCTHandler new pack - \(messageID) at unsafeMSCTPacks \n\(unsafeMSCTPacks)")
                pack.insertObject(msct, atIndex: 0)
            }
        } else {
//            dsLog("handleMSCT error")
        }
    }

    /// 发送msct检查 （如果msct超过1024byte，则进行包的拆分）
    ///
    /// - Parameters:
    ///   - request: 请求的实例
    ///   - maxSize: msct包的最大size
    /// - Returns: msct数组
    public func createMSCT(_ request: DinMSCTRequest, maxSize: Int) -> [MSCT] {
        var mscts = [MSCT]()
//        dsLog("MSCTHandler requestDict:\(request.requestData), payload size: \(request.requestData.bytes.count)")
//        DSLocalServerLogTools.logLocalInfo(message: "payload的data:\(request.requestData), payload size: \(request.requestData.bytes.count)")
//        dsLog("MSCTHandler requestPayload:\(String(describing: request.payload?.bytes))")
        if request.payload?.dataBytes.count ?? 0 > maxSize {
            let payloadPackages = request.payload?.chunkData(with: maxSize) ?? [Data]()
            for i in 0 ..< payloadPackages.count {
                request.options.append(OptionHeader(id: DinMSCTOptionID.total, data: String(payloadPackages.count).data(using: .utf8)))
                request.options.append(OptionHeader(id: DinMSCTOptionID.index, data: String(i).data(using: .utf8)))
                if let msct = try? MSCT(header: request.header, payload: payloadPackages[i], options: request.options) {
                    mscts.append(msct)
                }
            }
        } else {
            if let msct = try? MSCT(header: request.header, payload: request.payload, options: request.options) {
                mscts.append(msct)
            }
        }
        return mscts
    }

    private func packID(withMSCTType type: MessageType, messageID: String) -> String {
        return "\(messageID)_\(type)"
    }
}

extension DinMSCTHandler: DinMSCTPackageDelegate {
    func package(percentageOfCompletion percentage: Double) {
        delegate?.package(percentageOfCompletion: percentage)
    }

    func package(finish result: DinMSCTResult) {
        queue?.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }
            let packageID = self.packID(withMSCTType: result.type, messageID: result.messageID)
            // pack完成并包之后返回
//            dsLog("MSCTHandler pack complete - \(packageID) at self.unsafeMSCTPacks \n\(self.unsafeMSCTPacks))")
            // 组包完成后，发送通知处理对应结果
            self.delegate?.completePackage(result)
            DinSupportNotification.notifyCompleteMSCTPack(with: result)
            self.unsafeMSCTPacks.removeValue(forKey: packageID)
//            dsLog("MSCTHandler msctPacks delete \n\(self.unsafeMSCTPacks)")
        }
    }

    func package(timeout messageID: String, msctType: MessageType) {
        queue?.async(flags: .barrier) { [weak self] in
            guard let self = self else {
                return
            }
            let packageID = self.packID(withMSCTType: msctType, messageID: messageID)
            self.unsafeMSCTPacks.removeValue(forKey: packageID)
//            dsLog("MSCTHandler pack timeout - msctPacks delete \n\(self.unsafeMSCTPacks)")
        }
    }

    func package(requestResend messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType) {
        delegate?.requestResendPackages(with: messageID, indexes: indexes, fileType: fileType)
    }
}
