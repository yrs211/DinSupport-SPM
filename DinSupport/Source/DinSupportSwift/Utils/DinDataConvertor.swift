//
//  DinDataConvertor.swift
//  DinCore
//
//  Created by Jin on 2021/4/21.
//

import UIKit

public class DinDataConvertor {

    /// 把 String(JSON) 转成 [String: Any]
    /// - Parameter string: 字符串
    public class func convertToDictionary(_ string: String) -> [String: Any]? {
        guard let convertData = string.data(using: .utf8) else {
            return nil
        }
        guard let returnDic = convertToDictionary(convertData) else {
            return nil
        }
        return returnDic
    }

    /// 把 [String: Any] 转成 String
    /// - Parameter dict: 字典数据
    public class func convertToString(_ dict: [String: Any]) -> String? {
        guard let convertData = convertToData(dict) else {
            return nil
        }
        return convertToString(convertData)
    }

    /// 把 Data 转成 [String: Any]
    /// - Parameter data: Data
    public class func convertToDictionary(_ data: Data) -> [String: Any]? {
        guard let returnDic = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }
        return returnDic
    }

    /// 把 Data 转成 String
    /// - Parameter data: Data
    public class func convertToString(_ data: Data) -> String {
        return String(decoding: data, as: UTF8.self)
    }

    /// 把 [String: Any] 转成 Data
    /// - Parameter data: Data
    public class func convertToData(_ dict: [String: Any]) -> Data? {
        guard let convertData = try? JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions(rawValue: 0)) else {
            return nil
        }
        return convertData
    }

    public class func convertToJSONString(_ dict: [String: Any]) -> String {
        var dictString = "{"
        for i in 0 ..< dict.count {
            let key = Array(dict.keys)[i]
            dictString.append(contentsOf: "\"\(key)\":\"\(dict[key] ?? "unknow")\"")
            if i < dict.count - 1 {
                dictString.append(contentsOf: ",")
            }

        }
        dictString.append(contentsOf: "}")
        return dictString
    }
}
