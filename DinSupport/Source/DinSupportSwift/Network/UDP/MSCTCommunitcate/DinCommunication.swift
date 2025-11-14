//
//  DinCommunication.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

/// 为了防止参数过多，使用struct来传参
struct DinCommunicationParams {
    /// 数据加密器
    var dataEncryptor: DinCommunicationEncryptor
    /// 操作messageID
    var messageID: String
    /// 请求内容
    var request: DinMSCTRequest
    /// ACK 回调
    var ackCallback: DinCommunicationCallback?
    /// RESULT 回调
    var resultCallback: DinCommunicationCallback?
    /// 进度回调
    var progressCallback: ((Double) -> Void)?
    /// 操作重发次数（默认是2次）
    var resendTimes: Int?
    /// ACK超时时间
    var ackTimeoutSec: TimeInterval = 0
    /// RESULT超时时间
    var resultTimeoutSec: TimeInterval = 0

    init(with dataEncryptor: DinCommunicationEncryptor, messageID: String, request: DinMSCTRequest, resendTimes: Int?) {
        self.dataEncryptor = dataEncryptor
        self.messageID = messageID
        self.request = request
        self.resendTimes = resendTimes
    }
}

protocol DinCommunicationDelegate: NSObjectProtocol {
    func communication(requestSendData datas: [Data], withMessageID messageID: String)
    func communication(complete communication: DinCommunication)
    func communication(ackTimeout communication: DinCommunication)
    /// 获取到设备的result返回之后发送ack确认给设备
    func communication(requestActionResultReceived communication: DinCommunication, isProxy: Bool)
    /// 数据包组包缺失内容，请求重新发送
    func communication(_ communication: DinCommunication, requestResendPackages messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType, fileName: String?)
}


public class DinCommunication: NSObject {
    weak var delegate: DinCommunicationDelegate?
    /// 数据的加解密工具
    private(set) var dataEncryptor: DinCommunicationEncryptor

    // 重发次数 默认2次
    private let resendTimes: Int
    private var resendCount: Int = 0

    // 数据包处理器
    private lazy var msctHandler: DinMSCTHandler = {
        let msctHandler = DinMSCTHandler(with: dataEncryptor, combineAckPackTimeout: ackTimeout, resultTimeout: resultTimeout)
        msctHandler.delegate = self
        return msctHandler
    }()
    // 操作ID
    private(set) var messageID: String

    // ACK超时时间
    private var ackTimeout: TimeInterval = 6.0
    private var ackTimer: DinGCDTimer?
    private var ackReceived = false
    // ACK回调
    private var ackCallback: DinCommunicationCallback?
    // 等待ACK过程中是否需要重发
    private var needResend: Bool {
        resendTimes > 0
    }

    // Result超时时间
    private var resultTimeout: TimeInterval = 6.0
    private var resultTimer: DinGCDTimer?
    private var resultReceived = false
    // Result回调
    private var resultCallback: DinCommunicationCallback?

    // 接收进度回调
    private var progressCallback: ((Double) -> Void)?

    // 发送消息模块
    // 发送对象
    private var msctRequest: DinMSCTRequest
    // 获取到发送对象之后生成一系列的MSCT数据包
    private(set) var msctDatas = [MSCT]()

    // 接收消息模块
    private var msctResults = [DinMSCTResult]()

    /// 跟随当前Communication的生命周期，串行处理所有并发流程访问逻辑
    private let dataHandlerQueue: DispatchQueue

    deinit {
        stopAckCount()
        stopResultCount()
//        print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID) - deinit.")
    }

    init(with params: DinCommunicationParams) {
        self.dataEncryptor = params.dataEncryptor
        self.messageID = params.messageID
        self.msctRequest = params.request
        self.ackCallback = params.ackCallback
        self.resultCallback = params.resultCallback
        self.progressCallback = params.progressCallback
        self.resendTimes = params.resendTimes ?? 2
        self.dataHandlerQueue = DispatchQueue.init(label: "\(params.messageID).queue")
        if params.ackTimeoutSec > 0 {
            ackTimeout = params.ackTimeoutSec
        }
        if params.resultTimeoutSec > 0 {
            resultTimeout = params.resultTimeoutSec
        }
        super.init()
        //根据请求数据分包，组建msct
        msctDatas.removeAll()
        msctDatas = msctHandler.createMSCT(self.msctRequest, maxSize: 1024)
    }

    public func run() {
//        print("\(Date()) DinCommunication redesign test log - msgID\(messageID): begin run with resendtimes:\(resendTimes)")
        // 请求发送数据
        sendData()
        if msctRequest.header.msgType == .ACK {
            // 如果是发送ack，发送完成直接退出操作队列
        } else {
            beginAckCount()
        }
    }
}

// MARK: - 发送消息模块
extension DinCommunication {
    private func sendData(_ datas: [Data]) {
        delegate?.communication(requestSendData: datas, withMessageID: messageID)
    }

    private func sendData() {
        var datas = [Data]()
        for msct in msctDatas {
            if let data = try? msct.getData() {
                datas.append(data)
            }
        }
        sendData(datas)
    }

    /// 重发消息（操作的msct数据包是大包(个数大于一)不重发）
    private func resendData() {
        // 操作的msct数据包是大包(个数大于一)不重发
        if msctDatas.count > 1 {
            return
        }
        sendData()
    }
}

// MARK: - 接收消息模块
extension DinCommunication: DinMSCTHandlerDelegate {
    func package(percentageOfCompletion percentage: Double) {
        /// 收到的信息都在通道的线程里面，需要在主线程提交给上层处理
        DispatchQueue.main.async { [weak self] in
            self?.progressCallback?(percentage)
        }
    }

    /// 接收msct数据包
    ///
    /// - Parameter msct: msct数据包
    public func msctReceived(_ msct: MSCT) {
        msctHandler.receiveMSCT(msct)
    }

    func completePackage(_ result: DinMSCTResult) {
        if result.type == .ACK {
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID): completePackage ACK.")
            handleAckPackage(result)
        } else if result.type == .CON {
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID): completePackage RESULT.")
            handleResultPackage(result)
        }
    }

    func requestResendPackages(with messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType) {
        let requestDict = DinDataConvertor.convertToDictionary(msctRequest.requestData)
        let requestFileName = requestDict?["name"] as? String
        delegate?.communication(self, requestResendPackages: messageID, indexes: indexes, fileType: fileType, fileName: requestFileName)
    }
}

// MARK: - timeout模块
extension DinCommunication {
    // ACK
    private func beginAckCount() {
        // 0.2s 是最后给结束Ack Timeout缓冲一下的
        dataHandlerQueue.async { [weak self] in
            guard let self = self else { return }
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID): beginAckCount.")
            self.stopAckCount()
            // 重置重发
            self.resendCount = self.resendTimes
            let resendTimecount = (self.ackTimeout - 0.2)/TimeInterval(self.resendTimes+1)
            self.ackTimer = DinGCDTimer(timerInterval: .seconds(resendTimecount), isRepeat: true, executeBlock: { [weak self] in
                // global background queue
                self?.handleAckTimeout()
            })
        }
    }
    private func stopAckCount() {
        ackTimer = nil
    }
    private func handleAckTimeout() {
        dataHandlerQueue.async { [weak self] in
            guard let self = self else { return }
            // ack未收到，到时重发
            if self.resendCount < 1 {
                self.ackCompleted(.timout, info: self.messageID)
                self.delegate?.communication(ackTimeout: self)
//                print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID): return ack timeout.")
                return
            }
            if needResend {
                //请求重发信息
                self.resendData()
                self.resendCount -= 1
            }
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID): the \(self.resendTimes+1-self.resendCount) time handleAckTimeout")
        }
    }

    // RESULT
    private func beginResultCount() {
        dataHandlerQueue.async { [weak self] in
            guard let self = self else { return }
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID): beginResultCount.")
            self.stopResultCount()
            self.resultTimer = DinGCDTimer(timerInterval: .seconds(self.resultTimeout), isRepeat: false, executeBlock: { [weak self] in
                self?.handleResultTimeout()
            })
        }
    }
    private func stopResultCount() {
        resultTimer = nil
    }
    private func handleResultTimeout() {
        dataHandlerQueue.async { [weak self] in
            guard let self = self else { return }
            resultCompleted(.timout, info: self.messageID)
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID): handleResultTimeout.")
        }
    }
}

// MARK: - 其他
extension DinCommunication {
    private func handleAckPackage(_ msctResult: DinMSCTResult) {
        dataHandlerQueue.async { [weak self] in
            guard let self = self else { return }
            if msctResult.state == 0 {
                //成功
                self.ackCompleted(.success, info: msctResult)
            } else {
                //失败
                self.ackCompleted(.fail, info: msctResult.errorMessage)
            }
        }
    }

    private func handleResultPackage(_ msctResult: DinMSCTResult) {
        dataHandlerQueue.async { [weak self] in
            guard let self = self else { return }
            if msctResult.state == 0 || msctResult.fileType == .video || msctResult.fileType == .voice {
                //成功
                self.resultCompleted(.success, info: msctResult)
            } else {
                //失败
                self.resultCompleted(.fail, info: msctResult.errorMessage)
            }
        }
    }

    /// 停止计时器，通知代理请求操作完成
    private func completeCommunication() {
        delegate?.communication(complete: self)
    }

    /// ack流程完成
    ///
    /// - Parameter state: 结果
    private func ackCompleted(_ state: DinCommunicationCallbackState, info: Any) {
        // 防止在定时器到时，ack包刚好到的情况
        if ackReceived {
            return
        }
        // 标记
        ackReceived = true
        // 停止ack计时器
        stopAckCount()

        switch state {
        case .success:
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID) - ackCallback success.")
            ackCallback?.result(.success, info: info)
            if resultCallback == nil {
                // 如果没有Result监听，直接完成任务
                completeCommunication()
            } else {
                //开始resutl计时器
                beginResultCount()
            }
        case .fail:
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID) - ackCallback fail.")
            ackCallback?.result(.fail, info: info)
            //如果是失败，通知result超时
            resultCompleted(.timout, info: messageID)
            // 通知整个操作完成
            completeCommunication()
        case .timout:
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID) - ackCallback timeout.")
            ackCallback?.result(.timout, info: messageID)
            //如果是失败，通知result超时
            resultCompleted(.timout, info: messageID)
            // 通知整个操作完成
            completeCommunication()
        }
    }

    /// result流程完成
    ///
    /// - Parameter state: 结果
    private func resultCompleted(_ state: DinCommunicationCallbackState, info: Any) {
        // 防止在定时器到时，result包刚好到的情况
        if resultReceived {
            return
        }
        // 标记
        resultReceived = true
        //停止result计时器
        stopResultCount()

        switch state {
        case .success:
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID) - resultCallback success.")
            resultCallback?.result(.success, info: info)
            var isProxy = false
            if let result = info as? DinMSCTResult {
                isProxy = result.isProxyMSCT
            }
            delegate?.communication(requestActionResultReceived: self, isProxy: isProxy)
        case .fail:
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID) - resultCallback fail.")
            resultCallback?.result(.fail, info: info)
        case .timout:
//            print("\(Date()) DinCommunication redesign test log - msgID\(self.messageID) - resultCallback timeout.")
            resultCallback?.result(.timout, info: messageID)
        }

        // 通知整个操作完成
        completeCommunication()
    }
}
