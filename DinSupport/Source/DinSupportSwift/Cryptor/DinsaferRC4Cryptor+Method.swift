//
//  DinsaferRC4Cryptor+Method.swift
//  DinSupport
//
//  Created by Jin on 2021/9/8.
//

import Foundation

// MARK: - RC4加解密
extension DinsaferRC4Cryptor {
    /// 加密成data
    public func rc4EncryptToData(with data: Data, key: String) -> Data? {
        let nsData = data as NSData
        let encryData = nsData.crypto(withKey: key, isEncrypt: true)
        return encryData
    }
    /// 加密成data
    public func rc4EncryptToData(with str: String, key: String) -> Data? {
        guard key.count > 0 else { return nil }
        if let data = str.data(using: .utf8) {
            return rc4EncryptToData(with: data, key: key)
        }
        return nil
    }
    /// 加密成hex字符串
    public func rc4EncryptToHexString(with str: String, key: String) -> String? {
        return rc4EncryptToData(with: str, key: key)?.hexString
    }

    /// 解密字符串
    public func rc4Decrypt(_ data: Data, key: String) -> Data? {
        guard key.count > 0 else { return nil }
        let nsdata = data as NSData
        return nsdata.crypto(withKey: key, isEncrypt: false)
    }
    /// 解密字符串
    public func rc4DecryptHexString(_ str: String, key: String) -> String? {
        guard str.count > 0 else {
            return nil
        }
        if let data = str.hexData as Data? {
            if let decryptData = rc4Decrypt(data, key: key) {
                if let result = String(data: decryptData, encoding: .utf8) {
                    return result
                }
            }
        }
        return nil
    }
}
