//
//  DinsaferAESCBCCryptor+Method.swift
//  DinSupport
//
//  Created by Jin on 2021/9/8.
//

import Foundation

// MARK: - AES-CBC加解密
extension DinsaferAESCBCCryptor {
    /// AES加密字符串, 返回加密后data
    public func aesEncrypt(bytes: [UInt8]) -> [UInt8]? {
        guard bytes.count > 0 else { return nil }
        let nsdata = NSData(data: Data(bytes))
        return nsdata.aes_cbc_encrypt(with: Data(key), iv: Data(iv))?.bytes
    }
    /// AES加密字符串, 返回加密后data
    public func aesEncrypt(string: String) -> [UInt8]? {
        guard string.bytes.count > 0 else { return nil }
        let nsdata = NSData(data: Data(string.bytes))
        return nsdata.aes_cbc_encrypt(with: Data(key), iv: Data(iv))?.bytes
    }

    /// AES解密Data, 返回解密后的data
    public func aesDecrypt(bytes: [UInt8]) -> [UInt8]? {
        guard bytes.count > 0 else { return nil }
        let nsdata = NSData(data: Data(bytes))
        return nsdata.aes_cbc_decrypt(with: Data(key), iv: Data(iv))?.bytes
    }
}
