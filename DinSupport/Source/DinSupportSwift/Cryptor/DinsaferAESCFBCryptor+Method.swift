//
//  DinsaferAESCFBCryptor+Method.swift
//  DinSupport
//
//  Created by Jin on 2021/9/8.
//

import Foundation
import CryptoSwift

// MARK: - AES-CFB加解密
extension DinsaferAESCFBCryptor {
    /// AES-CFB加密字符串, 返回加密后data
    public func aesCFBEncrypt(data: [UInt8]) -> [UInt8]? {
        do {
            return try aes.encrypt(data)
        } catch {
            return nil
        }
    }
    /// AES加密字符串, 返回base64字符串
    public func aesCFBEncryptBase64(data: [UInt8]) -> String? {
        return aesCFBEncrypt(data: data)?.toBase64()
    }

    /// AES解密Data, 返回解密后的data
    public func aesCFBDecrypt(data: [UInt8]) -> [UInt8]? {
        do {
            return try data.decrypt(cipher: aes)
        } catch {
            return nil
        }
    }
    /// AES解密字符串, 返回解密后的字符串
    public func aesCFBDecryptBase64(string: String) -> String? {
        do {
            let decrypted = try string.decryptBase64ToString(cipher: aes)
            return decrypted
        } catch {
            return nil
        }
    }
}
