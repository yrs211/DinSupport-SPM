//
//  DinCommunicationEncryptor.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

/// 与设备进行数据交换的加密功能
public protocol DinCommunicationEncryptor {
    /// 如果是aes加密，需要在OptionHeader增加字段
    func checkOptionHeaders(_ headers: [OptionHeader]) -> [OptionHeader]

    /// 根据请求参数，加密成传送的Data
    /// - Parameter requestDict: 操作需要的数据（Data类型）
    func encryptedData(_ requestData: Data) -> Data?
    /// 根据收到的响应Data，解密成可以显示的Data
    /// - Parameters:
    ///   - responseData: 收到的加密后的响应Data
    ///   - msctHeaders: responseData所属的MSCT数据的 OptionHeader数据
    func decryptedData(_ responseData: Data, msctHeaders: [UInt8: OptionHeader]?) -> Data?

    /// 根据请求参数，加密成传送的KCP Data
    /// - Parameter requestDict: 操作需要的数据（Data类型）
    func encryptedKcpData(_ requestData: Data) -> Data?
    /// 根据收到的响应的Kcp Data，解密成可以显示的Data
    /// - Parameters:
    ///   - responseData: 收到的加密后的响应Data
    func decryptedKcpData(_ responseData: Data) -> Data?
}
