//
//  String+Extension.swift
//  MyTools
//
//  Created by Casten on 16/4/22.
//
//

import UIKit
import DinSupportObjC
public extension String {
    /// HMAC-SHA1
    func hmacSha1(key: String) -> String {
        if let cKey = key.cString(using: .utf8), let cData = self.cString(using: .utf8) {
            var result = [CUnsignedChar](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), cKey, strlen(cKey), cData, strlen(cData), &result)
            let data: NSData = NSData(bytes: result, length: Int(CC_SHA1_DIGEST_LENGTH))
            let base64Data = data.base64EncodedString(options: [])
            return String(base64Data).replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        }
        return self
    }

    /// 通过下标截取字符串
    subscript(i: Int) -> String {
        guard i >= 0 && i < self.count else { return "" }
        return String(self[index(startIndex, offsetBy: i)])
    }

    subscript(range: Range<Int>) -> String {
        let lowerIndex = index(startIndex, offsetBy: max(0, range.lowerBound), limitedBy: endIndex) ?? endIndex
        let upperIndex = (index(lowerIndex, offsetBy: range.upperBound - range.lowerBound, limitedBy: endIndex) ?? endIndex)
        return String(self[lowerIndex..<upperIndex])
    }

    subscript(range: ClosedRange<Int>) -> String {
        let lowerIndex = index(startIndex, offsetBy: max(0, range.lowerBound), limitedBy: endIndex) ?? endIndex
        let upperIndex = (index(lowerIndex, offsetBy: range.upperBound - range.lowerBound + 1, limitedBy: endIndex) ?? endIndex)
        return String(self[lowerIndex..<upperIndex])
    }

    /// 装换为NSString
    var nsstr: NSString { return self as NSString }

    /// 是否包含字符串
    func contains(_ find: String) -> Bool {
        return range(of: find) != nil
    }

    /// String 转 Bool
    func toBool() -> Bool {
        switch self {
        case "\"1\"", "True", "true", "yes", "1":
            return true
        default:
            return false
        }
    }

    /// 是否新版本
    func isNewerVersion(_ compareVersion: String) -> Bool {
        if self.compare(compareVersion, options: NSString.CompareOptions.numeric) == ComparisonResult.orderedDescending {
            return true
        }
        return false
    }

    func padLeftZero (width: Int) -> String {
        let toPad = width - self.count
        if toPad < 1 { return self }
        return "".padding(toLength: toPad, withPad: "0", startingAt: 0) + self
    }

    func binToDec() -> String {
        if let i = Int(self, radix: 2) {
            return String(i, radix: 10)
        }
        return ""
    }

    func hexToDec() -> Int {
        if let i = Int(self, radix: 16) {
            return i
        }
        return 0
    }

    /// 16进制字符串转2进制字符串
    func hexToBin() -> String {
        if let i = Int(self, radix: 16) {
            return String(i, radix: 2)
        }
        return self
    }

    /// 2进制字符串转16进制字符串
    func binToHex() -> String {
        if let i = Int(self, radix: 2) {
            return String(i, radix: 16, uppercase: true)
        }
        return self
    }

    /// 字符串转数组
    func toArray() -> [String] {
        return self.map { String($0) }
    }

    /// 16进制字符串 -> Data
    func dataFromHexadecimalString() -> Data? {
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

    /**
     MD5字符串
     
     - returns: MD5字符串
     */
    var md5: String {
        if let str = cString(using: String.Encoding.utf8) {
            let strLen = CC_LONG(lengthOfBytes(using: String.Encoding.utf8))
            let digestLen = Int(CC_MD5_DIGEST_LENGTH)
            let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)

            CC_MD5(str, strLen, result)

            let hash = NSMutableString()
            for i in 0 ..< digestLen {
                hash.appendFormat("%02x", result[i])
            }
            result.deinitialize(count: digestLen)
            result.deallocate()

            return String(format: hash as String)
        }
        return self
    }

    /**
     生成唯一ID
     
     - returns: String 唯一ID
     */
    static func UUID() -> String {
        let uuidStr = Foundation.UUID().uuidString
        let dateStr =  Date().timeIntervalSince1970
        let result = "\(uuidStr)\(dateStr)"
        return result.md5
    }

    /**
     获取字符串的宽度和高度
     
     - parameter font:    字体大小
     - parameter maxSize: 允许的最大宽度和高度
     
     - returns: CGRect
     */
    func getStringSize(withFont font: UIFont, maxSize: CGSize) -> CGSize {
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let attributes = [NSAttributedString.Key.font: font]
        let rect = self.boundingRect(with: maxSize, options: options, attributes: attributes, context: nil)
        return rect.size
    }

    func getStringWidth(withFont font: UIFont, maxWidth: CGFloat) -> CGFloat {
        let options: NSStringDrawingOptions = [.usesDeviceMetrics]
        let attributes = [NSAttributedString.Key.font: font]
        let size = CGSize(width: maxWidth, height: font.lineHeight)
        let rect = self.boundingRect(with: size, options: options, attributes: attributes, context: nil)
        return rect.size.width
    }

    /// 服务器返回的json字符串转Dictionary
    ///
    /// - Returns: json对象
//    func jsonObject() -> JSON? {
//        if let dataFromString = self.data(using: .utf8, allowLossyConversion: false) {
//            if let json = try? JSON(data: dataFromString) {
//                return json
//            }
//        }
//        return nil
//    }
    
}

extension String.StringInterpolation {
    /// 提供 `Optional` 字符串插值
    /// 而不必强制使用 `String(describing:)`
    public mutating func appendInterpolation(_ value: String?) {
        if let value = value {
            appendInterpolation(value)
        } else {
            appendLiteral("")
        }
    }
}

// 参考链接： https://stackoverflow.com/questions/30757193/find-out-if-character-in-string-is-emoji
//extension Character {
//    /// A simple emoji is one scalar and presented to the user as an Emoji
//    var isSimpleEmoji: Bool {
//        guard let firstProperties = unicodeScalars.first?.properties else {
//            return false
//        }
//        return unicodeScalars.count == 1 &&
//            (firstProperties.isEmojiPresentation ||
//                firstProperties.generalCategory == .otherSymbol)
//    }
//
//    /// Checks if the scalars will be merged into an emoji
//    var isCombinedIntoEmoji: Bool {
//        return (unicodeScalars.count > 1 &&
//               unicodeScalars.contains { $0.properties.isJoinControl || $0.properties.isVariationSelector })
//            || unicodeScalars.allSatisfy({ $0.properties.isEmojiPresentation })
//    }
//
//    var isEmoji: Bool {
//        return isSimpleEmoji || isCombinedIntoEmoji
//    }
//}

//extension String {
//    var isSingleEmoji: Bool {
//        return count == 1 && containsEmoji
//    }
//
//    var containsEmoji: Bool {
//        return contains { $0.isEmoji }
//    }
//
//    var containsOnlyEmoji: Bool {
//        return !isEmpty && !contains { !$0.isEmoji }
//    }
//
//    var emojiString: String {
//        return emojis.map { String($0) }.reduce("", +)
//    }
//
//    var emojis: [Character] {
//        return filter { $0.isEmoji }
//    }
//
//    var filterEmoji: [Character] {
//        return filter { !$0.isEmoji }
//    }
//    var emojiScalars: [UnicodeScalar] {
//        return filter { $0.isEmoji }.flatMap { $0.unicodeScalars }
//    }
//}
