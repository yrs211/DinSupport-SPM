//
//  DinMSCTOptionID.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

public enum DinMSCTOptionFileType: String {
    case unknown = "unknown"                // 其他类
    case jsonData = "application/json"      // json数据
    case voice = "audio/mpeg"               // 语音
    case video = "video/h265"               // 视频
    case bytes = "application/byte"         // 裸数据 [uint8]/Data
}

public struct DinMSCTOptionID {
    /// appid string
    static let appID = UInt8(0xB5)
    /// 自己的 id string
    static let sourceMSCTID = UInt8(0xA0)
    /// device 的 msct ID
    static let groupMSCTID = UInt8(0xA1)
    /// device 的 msct ID
    public static let destinationMSCTID = UInt8(0xA2)
    /// 加密的iv
    public static let aesIV = UInt8(0xA3)
    /// 序列号 (uint8) - 暂时用于p2p打洞时候的序列号确认
    static let seq = UInt8(0xA4)
    /// 目标device 的 msct ID，用于转发，可多个
    public static let proxyMSCTID = UInt8(0xF1)
    /// messageID
    static let msgID = UInt8(0xF6)
    /// service
    static let service = UInt8(0xB1)
    /// method
    public static let method = UInt8(0xF5)
//    static let method = UInt8(0xB2)
    /// 区域信息domain
    static let domain = UInt8(0xB3)
    /// sendFileFlag
    static let sendFile = UInt8(0xB6)
    /// 录音文件的时长
    static let voiceFileDuration = UInt8(0xB7)

    // MARK: - 返回
    /// status
    static let status = UInt8(0xC0)
    /// errorMessage
    static let errMsg = UInt8(0xC1)

    // MARK: - 拆包、并包相关
    /// 包的总个数
    static let total = UInt8(0x81)
    /// 包的index
    static let index = UInt8(0x82)
}
