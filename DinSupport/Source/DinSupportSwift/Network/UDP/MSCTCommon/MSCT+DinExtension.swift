//
//  MSCT+DinExtension.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import Foundation

extension MSCT {
    /// 获取MSCT的messageID
    ///
    /// - Returns: msct的messageID（若不能找到，返回空字符串）
    public func messageID() -> String {
        if let msgData = optionHeader?[DinMSCTOptionID.msgID]?.data {
            if let msgID = String(data: msgData, encoding: .utf8), msgID.count > 0 {
                return msgID
            }
        }
        return ""
    }

    /// 获取MSCT的messageID
    ///
    /// - Returns: msct的messageID（若不能找到，返回空字符串）
    public func fileType() -> DinMSCTOptionFileType {
        if let fileTypeData = optionHeader?[DinMSCTOptionID.sendFile]?.data {
            if let fileTypeString = String(data: fileTypeData, encoding: .utf8), fileTypeString.count > 0 {
                if let fileType = DinMSCTOptionFileType(rawValue: fileTypeString) {
                    return fileType
                } else {
                    return .unknown
                }
            }
        }
        return .unknown
    }
    
    /// 判断是否是代理模式的MSCT
    ///
    /// - Returns: msct的messageID（若不能找到，返回空字符串）
    public func isProxy() -> Bool {
        // 如果是代理模式，senderUniqueID设置为发送者id
        let proxyData = self.optionHeader?[DinMSCTOptionID.proxyMSCTID]?.data
        return (proxyData?.lyz_4BytesToInt() == 1 || proxyData?.lyz_1BytesToInt() == 1)
    }

    /// 获取数据的method数值
    ///
    /// - Returns: method数值（若不能找到，返回nil）
    public func method() -> [UInt8]? {
        return self.optionHeader?[DinMSCTOptionID.method]?.data?.bytes
    }
}
