//
//  DinMSCTResult.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

public class DinMSCTResult: NSObject {
    public private(set) var encryptor: DinCommunicationEncryptor
    /// 默认状态 1（检测不到msct中的optionHeader里面有state）
    static let defaultState: Int = 1
    /// 处理前的MSCT数组
    public var msctDatas: [MSCT]
    /// 处理后的Dictionary [当fileType == .jsonData 才会存在Dictionary]
    public var payloadDict = [String: Any]()
    /// 处理后的文件Data [当fileType == .voice或者fileType == .video Data会分开处理]
    public var payloadData: Data?
    /// msct的MessageType
    public var fileType: DinMSCTOptionFileType
    /// 是否是代理模式的消息
    public var isProxyMSCT: Bool
    /// 操作ID
    public var messageID: String
    /// msct的MessageType
    public var type: MessageType
    /// 结果状态 1标识成功
    public var state: Int = DinMSCTResult.defaultState
    /// 失败信息
    public var errorMessage: String = ""
    /// method
    public var method: [UInt8]? {
        msctDatas.first?.method()
    }

    public init(withMSCTDatas msctDatas: [MSCT],
                messageID: String,
                encryptor: DinCommunicationEncryptor,
                type: MessageType,
                fileType: DinMSCTOptionFileType,
                optionHeader: [UInt8: OptionHeader]?) {
        self.encryptor = encryptor
        self.msctDatas = msctDatas
        self.messageID = messageID
        if (self.msctDatas.count > 0) {
            self.isProxyMSCT = msctDatas[0].isProxy()
            
        } else {
            self.isProxyMSCT = false
        }
        self.type = type
        self.fileType = fileType
        super.init()
        checkInfo(withOptionHeader: optionHeader)
    }

    private func checkInfo(withOptionHeader optionHeader: [UInt8: OptionHeader]?) {
        // ACK处理Status, 从optionHeader检测status是否成功
        if type == .ACK {
            if let statusData = optionHeader?[DinMSCTOptionID.status]?.data {
                //获取到的数据是以字符的形式返回，所以直接转成String，再强制转成Int
                state = statusData.lyz_2BytesToInt()
            }
            //检查错误信息
            if let errMsgData = optionHeader?[DinMSCTOptionID.errMsg]?.data {
                errorMessage = String(bytes: errMsgData, encoding: .utf8) ?? ""
            }
            configACKData()
        } else if type == .CON {
            // RESULT处理Status, 从payload检测status是否成功
            configCONData()
        } else if type == .NON {
            // 处理NOCON
            configNOCONData()
        }
    }

    /// 处理ACK回复
    private func configACKData() {
        if fileType == .video || fileType == .voice {
            // 语音文件和视频文件，需要分开加密处理
            payloadData = decryptSeperate()
        } else {
            if let decryptData = decryptAfterCombined() {
                payloadData = decryptData
                if let decryptString = String(data: decryptData, encoding: .utf8) {
                    payloadDict = DinDataConvertor.convertToDictionary(decryptString) ?? [:]
                } else {
                    payloadDict = [:]
                }
            } else {
                payloadDict = [:]
            }
        }
    }

    /// 处理CON回复
    private func configCONData() {
        if fileType == .video || fileType == .voice {
            // 语音文件和视频文件，需要分开加密处理
            payloadData = decryptSeperate()
        } else {
            if let decryptData = decryptAfterCombined() {
                payloadData = decryptData
                if let decryptString = String(data: decryptData, encoding: .utf8) {
                    let resultDict = DinDataConvertor.convertToDictionary(decryptString) ?? [:]
                    state = resultDict["status"] as? Int ?? DinMSCTResult.defaultState
                    errorMessage = resultDict["errormessage"] as? String ?? ""
                    payloadDict = resultDict
                } else {
                    state = DinMSCTResult.defaultState
                    errorMessage = ""
                    payloadDict =  [:]
                }
            } else {
                state = DinMSCTResult.defaultState
                errorMessage = ""
                payloadDict =  [:]
            }
        }
    }

    /// 处理NOCON回复
    private func configNOCONData() {
        if let decryptData = decryptAfterCombined() {
            payloadData = decryptData
            if let decryptString = String(data: decryptData, encoding: .utf8) {
                let resultDict = DinDataConvertor.convertToDictionary(decryptString) ?? [:]
                state = resultDict["status"] as? Int ?? DinMSCTResult.defaultState
                errorMessage = resultDict["errormessage"] as? String ?? ""
                payloadDict = resultDict
            } else {
                state = DinMSCTResult.defaultState
                errorMessage = ""
                payloadDict =  [:]
            }
        } else {
            state = DinMSCTResult.defaultState
            errorMessage = ""
            payloadDict =  [:]
        }
    }

    /// 将MSCT数组先合并再解密
    /// - Returns: 解密后的Data
    private func decryptAfterCombined() -> Data? {
        var combineData = [UInt8]()
        for i in 0 ..< msctDatas.count {
            if let payload = msctDatas[i].payload {
                combineData.append(contentsOf: payload.dataBytes)
            }
        }
        return encryptor.decryptedData(Data(combineData), msctHeaders: msctDatas.first?.optionHeader)
    }

    /// 将MSCT数组先解密再合并
    /// - Returns: 解密后的Data
    private func decryptSeperate() -> Data {
        var data = Data()
        for i in 0 ..< msctDatas.count {
            let msct = msctDatas[i]
            if let payload = msct.payload {
//                dsLog("pack index: \(i)  - size: \(msct.payload?.bytes.count)")
//                data.append(payload)
                if let decryptData = encryptor.decryptedData(payload, msctHeaders: msctDatas.first?.optionHeader) {
                    data.append(decryptData)
                }
            }
        }
        return data
    }
}
