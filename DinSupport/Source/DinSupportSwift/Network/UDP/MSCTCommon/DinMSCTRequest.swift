//
//  DinMSCTRequest.swift
//  DinSupport
//
//  Created by Jin on 2021/5/4.
//

import UIKit

class DinMSCTRequest: NSObject {
    /// 加密前的Data
    private(set) var requestData: Data
    /// 加密后的payload
    private(set) var payload: Data?
    /// 请求需要的MSCT Header
    var header: Header
    /// 请求需要的MSCT OptionHeader数组
    var options: [OptionHeader]

    /// 操作生成响应的实例
    ///
    /// - Parameters:
    ///   - requestData: 操作payload数据（Data类型）
    ///   - encryptor: 通讯的加解密对象
    ///   - optionHeader: MSCT的OptionHeader数组
    init?(withRequestDict requestData: Data, encryptor: DinCommunicationEncryptor, header: Header, optionHeader: [OptionHeader]) {
        if requestData.count < 1 {
            self.requestData = Data()
            self.header = header
            self.options = encryptor.checkOptionHeaders(optionHeader)
            self.payload = Data()
        } else if let encryptedData = encryptor.encryptedData(requestData) {
            // 组装内容发送
            self.requestData = requestData
            self.header = header
            self.options = encryptor.checkOptionHeaders(optionHeader)
            self.payload = encryptedData
        } else {
            return nil
        }
    }
}
