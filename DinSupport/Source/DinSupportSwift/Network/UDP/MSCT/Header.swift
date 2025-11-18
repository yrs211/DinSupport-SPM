//
//  Header.swift
//  DinsaferSDK
//
//  Created by Casten on 2019/7/16.
//  Copyright © 2019 Dinsafer. All rights reserved.
//

import Foundation

/* Header 的组成 1byte
 |------+-------------+--------------------------------------------|
 | 2bit | 消息类型     | (ACK) (CON) (NOCON) (QOS)                  |
 | 5bit | 管道        | 0:并发管道, 与顺序无关 (默认)                  |
 | 1bit | 是否拥有扩展 | (Option header)                            |
 |------+------------+--------------------------------------------|
 */

/// MSCT的消息类型
public enum MessageType: UInt8 {
    /// NonConfirmable
    case NON = 0b1100
    /// Confirmable
    case CON = 0b1101
    /// Acknowledgement
    case ACK = 0b1110
    /// 特殊类型
    case QOS = 0b1111
}

/// MSCT的管道类型
public enum Channel: UInt8 {
    /// 0: 并发管道1
    case ASYNCCHAN1 = 0
    /// 1: 并发管道2
    case ASYNCCHAN2
    /// 2: 并发管道3
    case ASYNCCHAN3
    /// 3: 并发管道4
    case ASYNCCHAN4
    /// 4: 普通顺序管道1
    case NORCHAN1
    /// 5: 普通顺序管道2
    case NORCHAN2
    /// 6: 普通顺序管道3
    case NORCHAN3
    /// 7: 普通顺序管道4
    case NORCHAN4
    /// 8: 媒体管道1
    case MEDCHAN1
    /// 9: 媒体管道2
    case MEDCHAN2
    /// 10: 音频管道1
    case VOICECHAN1
    /// 11: 音频管道2
    case VOICECHAN2
    /// 12: 数据管道 1
    case DATASCHAN1
    /// 13: 数据管道 2
    case DATASCHAN2
    /// 14: 数据管道 3
    case DATASCHAN3
    /// 15-31: 扩展管道, 如有需要可自行定义
    case EXTCHAN1
}

public struct Header {
    /// 消息类型
    public var msgType: MessageType
    /// 管道
    public var channel: Channel
    /// 初始化Header对象
    public init(msgType: MessageType, channel: Channel) {
        self.msgType = msgType
        self.channel = channel
    }
}

extension Header {
    /// 初始化 根据传入的byte生成MSCT的Header对象
    public init?(byte: UInt8) {
        // MessageType 2bit,利用与运算 11000000 进行纠错 , Channel 5bit 利用与运算 00111110进行纠错
        if let type = MessageType(rawValue: (byte & 0b11110000) >> headerMsgTypeIndex),
            let chan = Channel(rawValue: (byte & 0b00001110) >> headerChannelIndex) {
            msgType = type
            channel = chan
        } else {
            return nil
        }
    }

    func parseOption(bytes: [UInt8]) -> (options: [OptionHeader]?, length: Int) {
        // 小于Header+OptionHeader长度 不合法
        if bytes.count < (minHeaderLength + minOptionHeaderLength) {
            return (nil, -1)
        }

        var options = [OptionHeader]()
        var length = 0

        /* 数据格式
         |---------+------------------------+--------------------+-----------------------------------|
         | UDP/TCP | 3byte                  | OPTION HEADER      |                                   |
         |---------+------------------------+--------------------+-----------------------------------|
         |         | 1bit                   | 是否具有下一个扩展    |                                   |
         |         | 7bit                   | 扩展协议长度         | 支持 128 字节                      |
         |         | 8bit/1byte             | 扩展标识类型         | 扩展协议最大为 256 扩展协议           |
         |         | 1byte +                | 扩展协议数据         |                                   |
         |---------+------------------------+--------------------+-----------------------------------|
         */

        // 去除描述字节
        var tmpBytes = Array(bytes.suffix(from: 1))

        // 解释
        var next = true
        while next {
            // 获取option长度
            let opt = getOptionLength(bytes: tmpBytes)
            if tmpBytes.count < opt.length + minOptionHeaderLength {
                return (options, -1)
            }

            let id = getOptionID(bytes: tmpBytes)
            var data: Data?
            if opt.length > 0 {
                data = Array(tmpBytes[minOptionHeaderLength ... minOptionHeaderLength+opt.length-1]).data
            }
            let optHeader = OptionHeader(id: id, data: data)
            options.append(optHeader)

            // 信息合法进行递增运算
            let total = minOptionHeaderLength + opt.length
            length += total

            // 裁剪头部数据
            tmpBytes = Array(tmpBytes.suffix(from: total))
            next = opt.hasNext
        }

        return (options, length)
    }

    fileprivate func getOptionID(bytes: [UInt8]) -> UInt8 {
        if bytes.count < minOptionHeaderLength {
            return 0x00
        }
        return bytes[1]
    }

    fileprivate func getOptionLength(bytes: [UInt8]) -> (length: Int, hasNext: Bool) {
        if bytes.count < minOptionHeaderLength {
            return (-1, false)
        }
        let byte = bytes[0]
        // 利用与运算 01111111进行纠错
        let length = Int(byte & 0b01111111)
        if (byte & 0b10000000) == 0 {
            return (length, false)
        }
        return (length, true)
    }
}

public struct OptionHeader {
    /// 扩展协议标识, 一共支持256个扩展协议
    public var id: UInt8
    /// 扩展协议的内容, 不可大于128 byte
    public var data: Data?
    /// 初始化OptionHeader
    public init(id: UInt8, data: Data?) {
        self.id = id
        self.data = data
    }
}

extension OptionHeader {
    /// 检查OptionHeader是否有效
    public func isValid() -> Bool {
        if data?.count ?? 0 > maxOptionLength {
            return false
        }
        return true
    }

    /// OptionHeader对象转Bytes
    public var bytes: [UInt8]? {
        if !isValid() {
            return nil
        }
        var results: [UInt8] = []
        results.append(UInt8(data?.count ?? 0) & 0b01111111)
        results.append(id)
        if let `data` = data {
            results.append(contentsOf: data.dataBytes)
        }
        return results
    }
}
