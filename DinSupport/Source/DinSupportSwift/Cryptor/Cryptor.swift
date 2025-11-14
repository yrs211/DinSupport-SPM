//
//  Cryptor.swift
//  DinsaferSDK
//
//  Created by Casten on 2019/7/1.
//  Copyright © 2019 Dinsafer. All rights reserved.
//

import Foundation
import CryptoSwift

public class DinsaferRC4Cryptor {
    public init() {}
}

public class DinsaferAESCBCCryptor {
    let aes: AES

    let key: [UInt8]
    let iv: [UInt8]

    /// 新建加解密器，如果secret数组不是32，iv数组不是16，加解密器会失效
    /// - Parameters:
    ///   - secret: 秘钥
    ///   - iv: iv
    public init?(withSecret secret: [UInt8], iv: [UInt8]) {
        guard secret.count == 32 else { return nil }
        guard iv.count == 16 else { return nil }
        self.key = secret
        self.iv = iv
        do {
            self.aes = try AES(key: secret, blockMode: CBC(iv: iv))
        } catch {
            return nil
        }
    }
}

public class DinsaferAESCFBCryptor {
    let aes: AES

    /// 新建加解密器，如果secret数组不是32，iv数组不是16，加解密器会失效
    /// - Parameters:
    ///   - secret: 秘钥
    ///   - iv: iv
    public init?(withSecret secret: [UInt8], iv: [UInt8]) {
        guard secret.count == 32 else { return nil }
        guard iv.count == 16 else { return nil }
        do {
            self.aes = try AES(key: secret, blockMode: CFB(iv: iv), padding: .noPadding)
        } catch {
            return nil
        }
    }
}

extension Data {
    /// Data -> 16进制字符串
    var hexString: String {
        var str = ""
        str.reserveCapacity(count * 2)

        for byte in self {
            str.append(String(format: "%02x", byte))
        }

        return str
    }
}

extension String {
    /// 16进制字符串 -> Data
    var hexData: Data? {
        let trimmedString = self.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")).replacingOccurrences(of: " ", with: "")

        do {
            let regex = try NSRegularExpression(pattern: "^[0-9a-f]*$", options: .caseInsensitive)
            if let found = regex.firstMatch(in: trimmedString, range: NSRange(location: 0, length: trimmedString.utf16.count)) {
                if found.range.location == NSNotFound || trimmedString.count % 2 != 0 {
                    return nil
                }
            } else {
                return nil
            }

            var data = Data(capacity: trimmedString.count / 2)
            var index = trimmedString.startIndex
            while index < trimmedString.endIndex {
                let nextIndex = trimmedString.index(index, offsetBy: 2)
                let byteString = String(trimmedString[index..<nextIndex])
                if let num = UInt8(byteString, radix: 16) {
                    data.append(num)
                    index = nextIndex
                }
            }

            return data
        } catch {
            return nil
        }
    }
}
