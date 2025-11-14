//
//  MSCT.swift
//  DinsaferSDK
//
//  Created by Casten on 2019/7/1.
//  Copyright © 2019 Dinsafer. All rights reserved.
//

import Foundation

public enum MSCTError: Error {
    case payloadOver1024
    case dataOverlow
    case invalidHeader
    case invalidOption
}

/// value = 1   扩展字节总长度不得大于256字节
let minHeaderLength = 1
/// value = 2   option header的最小协议长度
let minOptionHeaderLength = 2
/// value = 1024    UDP协议下, 单数据包不得大于1024字节
let maxPayloadLength = 1024
/// value = 256   Header总长度不得大于256字节
let maxHeaderLength = 256
/// value = 128     扩展协议内容长度不得超过128字节
let maxOptionLength = 128
/// value = 6   header msgType的index
let headerMsgTypeIndex = 4
/// value = 1   header channel的index
let headerChannelIndex = 1

/// MSCT: Message Secure Channel Transport 消息安全管道传输
public struct MSCT {
    /// header 必须定义
    public var header: Header
    /// optionHeader 可选
    public var optionHeader: [UInt8: OptionHeader]?
    /// payload  需要传输的内容
    public var payload: Data?

    /// 创建MSCT对象
    public init(header: Header, payload: Data?, options: [OptionHeader]?) throws {
        if payload?.count ?? 0 > maxPayloadLength {
            throw MSCTError.payloadOver1024
        }
        self.header = header
        self.payload = payload
        if let `options` = options {
            self.optionHeader = [:]
            for option in options {
                self.optionHeader?[option.id] = option
            }
        }
    }

    /// 根据传入的数据生成MSCT对象
    public init(data: Data) throws {
        let bytes = data.bytes

        // 少于Header长度 不合法
        if bytes.count < minHeaderLength {
            throw MSCTError.invalidHeader
        }

        // 大于最大限制UDP数据以及头文件的大小总和 不合法
        if bytes.count > (maxPayloadLength + maxHeaderLength) {
            throw MSCTError.dataOverlow
        }

        let byte0 = bytes[0]
        // 创建Header
        if let header = Header(byte: byte0) {
            self.header = header
        } else {
            throw MSCTError.invalidHeader
        }

        var payloadIdx = 1

        // 如果Header有扩展
        if byte0 & 0b00000001 == 1 {
            // 创建optionHeader
            optionHeader = [UInt8: OptionHeader]()
            let opts = header.parseOption(bytes: bytes)
            if opts.length == -1 {
                throw MSCTError.invalidOption
            }
            for opt in opts.options ?? [] {
                optionHeader?[opt.id] = opt
            }
            payloadIdx += opts.length
        }

        // 创建payload
        if bytes.count > minHeaderLength {
            payload = Array(bytes.suffix(from: payloadIdx)).data
        }
    }

    // MSCT对象的Data
    public func getData() throws -> Data {
        // 判断传输内容是否超出UDP限制
        if payload?.count ?? 0 > maxPayloadLength {
            throw MSCTError.payloadOver1024
        }

        var results: [UInt8] = []

        // 合并Header字节
        let msgTypeBs = (header.msgType.rawValue << headerMsgTypeIndex) & 0b11110000
        let chanBs = (header.channel.rawValue << headerChannelIndex) & 0b00001110

        // 判断是否拥有扩展协议
        var hasOptionHeader: UInt8 = 0
        if optionHeader?.count ?? 0 > 0 {
            hasOptionHeader = 1
        }

        // 利用或运算合成字节
        let headerByte = msgTypeBs | chanBs | hasOptionHeader
        results.append(headerByte)

        // 合并optionHeader字节
        // 将无序map转成有序数组
        var options: [OptionHeader] = []
        for (_, value) in optionHeader ?? [:] {
            options.append(value)
        }

        // 处理其扩展协议
        for (index, value) in options.enumerated() {
            if var bytes = value.bytes {
                // 判断是否最后一个扩展协议
                if index < options.count - 1 {
                    // 对第一个字节第一个bit进行改写
                    bytes[0] = bytes[0] | 0b10000000
                }
                results.append(contentsOf: bytes)
            }
        }

        // 判断协议是否大于限定值
        if results.count > maxHeaderLength {
            throw MSCTError.invalidOption
        }

        // 插入数据
        if let `payload` = payload {
            results.append(contentsOf: payload.bytes)
        }

        return results.data
    }
}

public extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}

public extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}
