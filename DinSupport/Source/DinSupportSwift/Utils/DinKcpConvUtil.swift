//
//  DinKcpConvUtil.swift
//  DinSupport
//
//  Created by Jin on 2021/6/30.
//

import Foundation

public enum DinKcpType: UInt8 {
    case cmd
    case hd
    case std
    case jsonCmd
    case getPic
    case audio
    case talk
    case downloadRecord
    case p2pHandShake
}

public class DinKCPConvUtil {

    /// 通过自定义的kcp type获取两个byte
    /// 第一个byte的前两bit写死10, 接着的6个bit是自定义Type, 6位二进制数
    /// 第二个byte暂定为0
    private static func typeBytes(_ type: DinKcpType) -> [UInt8] {
        // 默认错误
        var bytes: [UInt8] = [0]

        switch type {
        case .cmd:
            bytes.append(contentsOf: [0b10000001])
        case .hd:
            bytes.append(contentsOf: [0b10000010])
        case .std:
            bytes.append(contentsOf: [0b10000011])
        case .jsonCmd:
            bytes.append(contentsOf: [0b10000100])
        case .getPic:
            bytes.append(contentsOf: [0b10000101])
        case .audio:
            bytes.append(contentsOf: [0b10000110])
        case .talk:
            bytes.append(contentsOf: [0b10000111])
        case .downloadRecord:
            bytes.append(contentsOf: [0b10001001])
        case .p2pHandShake:
            bytes.append(contentsOf: [0b10001011])
        }
        return bytes
    }

    /// 获取ChannelID，定义为Conv的前两个byte
    /// Conv是由4个byte组成的无符号整形UInt32
    public static func channelIDWithType(_ type: DinKcpType) -> UInt16? {
        // 根据自定义的kcpType确定前两个Byte
        let convBytes: [UInt8] = typeBytes(type)
        return UInt16(Data(convBytes).lyz_2BytesToInt())
    }
    /// 获取Kcp的Conv
    /// Conv是由4个byte组成的无符号整形UInt32
    public static func convWithType(_ type: DinKcpType, sessionID: UInt16) -> UInt32? {
        // 根据自定义的kcpType确定前两个Byte
        var convBytes: [UInt8] = Int(sessionID).lyz_to2Bytes()
        // 再根据sessionID组成后两个Byte
        convBytes.append(contentsOf: typeBytes(type))
        if convBytes.count == 4 {
            return UInt32(Data(convBytes).lyz_4BytesToInt())
        }
        return nil
    }

    /// 生成Session，定义为Conv的后两个byte
    /// Conv是由4个byte组成的无符号整形UInt32
    public static func genSessionID() -> UInt16 {
        let value: UInt16 = UInt16((arc4random() % 65530) + 1);
        return value
    }
}
