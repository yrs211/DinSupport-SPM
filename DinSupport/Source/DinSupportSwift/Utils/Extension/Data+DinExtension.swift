//
//  Data+DSExtension.swift
//  HelioSDK
//
//  Created by Jin on 2020/1/29.
//  Copyright © 2020 Dinsafer. All rights reserved.
//

import Foundation

public extension Data {

    var dataBytes: [UInt8] {
        return [UInt8](self)
    }

    /**
     NSData -> 16进制字符串
     
     - returns: 16进制字符串
     */
    func hexadecimalString() -> String {
        var hexString = ""
        hexString.reserveCapacity(count * 2)

        for byte in self {
            hexString.append(String(format: "%02X", byte))
        }

        return hexString
    }

    // 拆分Data包
    func chunkData(with maxSize: Int) -> [Data] {
        var chunks = [Data]()

        let partCount = Int(count/maxSize)

        for i in 0 ..< partCount {
            chunks.append(subdata(in: i*maxSize ..< (i+1)*maxSize))
        }
        let sizeRemain = count - partCount*maxSize
        if sizeRemain > 0 {
            chunks.append(subdata(in: count - sizeRemain ..< count))
        }
        return chunks
    }

    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }

    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0) })
        return value
    }

    //1bytes转Int
    func lyz_1BytesToInt() -> Int {
        var value : UInt8 = 0
        let data = NSData(bytes: [UInt8](self), length: self.count)
        data.getBytes(&value, length: self.count)
        value = UInt8(bigEndian: value)
        return Int(value)
    }

    //2bytes转Int
    func lyz_2BytesToInt() -> Int {
        var value : UInt16 = 0
        let data = NSData(bytes: [UInt8](self), length: self.count)
        data.getBytes(&value, length: self.count)
        value = UInt16(bigEndian: value)
        return Int(value)
    }

    //4bytes转Int
    func lyz_4BytesToInt() -> Int {
        var value : UInt32 = 0
        let data = NSData(bytes: [UInt8](self), length: self.count)
        data.getBytes(&value, length: self.count)
        value = UInt32(bigEndian: value)
        return Int(value)
    }
}
