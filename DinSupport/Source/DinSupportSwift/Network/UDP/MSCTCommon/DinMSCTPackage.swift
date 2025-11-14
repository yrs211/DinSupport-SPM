//
//  DinMSCTPackage.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

protocol DinMSCTPackageDelegate: NSObjectProtocol {
    /// 组包成功
    /// - Parameter result: 成功后的RESULT对象
    func package(finish result: DinMSCTResult)

    /// 当组包需要的小包数还没有齐全，重新向设备请求缺失的小包
    /// - Parameters:
    ///   - messageID: 通信的MessageID
    ///   - indexes: 缺失的包的indexes
    ///   - fileType: 包的类型
    func package(requestResend messageID: String, indexes: [Int], fileType: DinMSCTOptionFileType)

    /// 组包的完成度
    /// - Parameter percentage: 百分比（Double, 小数点后3位） eg. 0.321
    func package(percentageOfCompletion percentage: Double)

    /// 组包超时（超时时间参考Communication的result timeout）
    /// - Parameters:
    ///   - messageID: 通信的MessageID
    ///   - msctType: 通信的类型
    func package(timeout messageID: String, msctType: MessageType)
}

class DinMSCTPackage: NSObject {

    weak var delegate: DinMSCTPackageDelegate?
    /// 数据的加解密工具
    private var dataEncryptor: DinCommunicationEncryptor

    private var mscts = [Int: MSCT]()
    private var total: Int
    public var messageID: String
    private var msctType: MessageType
    private var msctFileType: DinMSCTOptionFileType

    // 重新申请分包定时器
    private var timer: DinGCDTimer?

    // 申请分包的时间
    private var resendTimeout: TimeInterval
    // 根据定死的resendTimes生成动态的请求计数，先定为2次
    private let resendTimes = 2
    private var resendCount: Int = 2

    deinit {
        stopCount()
    }

    /// 检查是否有相关的MessageID、MessageType、msct是否需要并包（判断msct的包数>0）ID
    /// 如果没有MessageID则初始化失败，返回nil
    ///
    /// - Parameter msct: msct实例
    init?(withMSCT msct: MSCT, dataEncryptor: DinCommunicationEncryptor, timeout: TimeInterval) {
        self.dataEncryptor = dataEncryptor
        let msgID = msct.messageID()
        if msgID.count > 0 {
            //messageID
            self.messageID = msgID
            // 申请分包的时间，0.1是为了每次都比总的请求包超时少
            self.resendTimeout = timeout - 0.1
            self.msctType = msct.header.msgType
            self.msctFileType = msct.fileType()
            if let totalData = msct.optionHeader?[DinMSCTOptionID.total]?.data {
                self.total = Int(String(data: totalData, encoding: .utf8) ?? "1") ?? 1
            } else {
                self.total = 1
            }
            super.init()
            if self.total > 1 {
                //需要分包的时候才会倒数
                beginCount()
            }
        } else {
            return nil
        }
    }

    public func append(msct: MSCT) {
        if let indexData = msct.optionHeader?[DinMSCTOptionID.index]?.data {
            if let indexString = String(data: indexData, encoding: .utf8), let index = Int(indexString) {
//                dsLog("MSCTPackage package \(messageID) \n received  number\(index) data")
                insertObject(msct, atIndex: index)
            }
        }
    }

    public func insertObject(_ msct: MSCT, atIndex index: Int) {
        guard index < total else {
            return
        }
        mscts.updateValue(msct, forKey: index)
//        dsLog("MSCTPackage package \(messageID) \nneed \(total) pack\n \(total - mscts.count) pack left")
        // 提交进度
        let percentage: Double = (Double(mscts.count)/Double(total)).rounded(toPlaces: 3)
        delegate?.package(percentageOfCompletion: percentage)
        if mscts.count == total {
            combineMSCT()
//            dsLog("MSCTPackage package \(messageID) received  all .. complete")
        }
    }
}

// MARK: - 定时器
extension DinMSCTPackage {
    /// 开始计时
    private func beginCount() {
//        dsLog("MSCTPackage beginCount -- \(messageID)")
        let interval = resendTimeout/TimeInterval(resendTimes+1)
        timer = DinGCDTimer(timerInterval: .seconds(interval), isRepeat: true, executeBlock: { [weak self] in
            self?.requestPackages()
        })
    }

    /// 停止计时
    private func stopCount() {
        timer = nil
    }

    private func requestPackages() {
//        dsLog("MSCTPackage \(messageID) requestPackages resendCount \(resendCount)")
        if resendCount < 1 {
            stopCount()
            delegate?.package(timeout: messageID, msctType: msctType)
        } else {
//            dsLog("MSCTPackage requestPackages:\(packsLeft())")
            delegate?.package(requestResend: messageID, indexes: packsLeft(), fileType: msctFileType)
        }
        resendCount -= 1
    }
}

// MARK: - 并包处理
extension DinMSCTPackage {
    /// 剩下的包的index数组
    ///
    /// - Returns: 剩下的包的index数组
    private func packsLeft() -> [Int] {
        var packsLeft = [Int]()
        for i in 0 ..< total where mscts[i] == nil {
            packsLeft.append(i)
        }
        return packsLeft
    }

    /// 合成MSCT包
    private func combineMSCT() {
        guard mscts.count > 0 else {
            return
        }
        stopCount()
        var msctArr = [MSCT]()
        for i in 0 ..< total {
            if let msct = mscts[i] {
                msctArr.append(msct)
            }
        }
        let result = DinMSCTResult(withMSCTDatas: msctArr,
                                  messageID: messageID,
                                  encryptor: dataEncryptor,
                                  type: msctType,
                                  fileType: msctFileType,
                                  optionHeader: mscts[0]?.optionHeader)
        delegate?.package(finish: result)
    }
}
