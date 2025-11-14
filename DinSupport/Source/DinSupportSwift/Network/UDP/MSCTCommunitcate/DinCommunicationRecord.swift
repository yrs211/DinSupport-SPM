//
//  DinCommunicationRecord.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

enum DinCommunicationRecordState {
    case receiving
    case received
}

protocol DinCommunicationRecordDelegate: NSObjectProtocol {
    /// Communication处理记录过期
    ///
    /// - Returns: CommunicationRecord
    func recordExpire(_ record: DinCommunicationRecord)
}

class DinCommunicationRecord: NSObject {
    weak var delegate: DinCommunicationRecordDelegate?

    /// 标识操作的唯一ID
    public var crID: String {
        return DinCommunicationRecord.getCommunicationRecordID(with: messageID, type: type)
    }

    private(set) var messageID: String
    private(set) var type: MessageType
    public var state: DinCommunicationRecordState

    private var timer: DinGCDTimer?

    init(with msct: MSCT) {
        messageID = msct.messageID()
        type = msct.header.msgType
        // default
        state = .received
        // 检查是否需要并包
        if let totalData = msct.optionHeader?[DinMSCTOptionID.total]?.data {
            if Int(String(data: totalData, encoding: .utf8) ?? "1") ?? 1 > 1 {
                state = .receiving
            }
        }
        super.init()
        // 过期计时
        beginCount()
    }

    deinit {
        stopCount()
    }
}

// MARK: - 计时器
extension DinCommunicationRecord {
    private func beginCount() {
        timer = DinGCDTimer(timerInterval: .seconds(120), isRepeat: false, executeBlock: { [weak self] in
            self?.timesUp()
        })
    }

    private func stopCount() {
        timer = nil
    }

    private func timesUp() {
        delegate?.recordExpire(self)
        stopCount()
    }
}

extension DinCommunicationRecord {
    public class func getCommunicationRecordID(with messageID: String, type: MessageType) -> String {
        return messageID + "_" + "\(type)"
    }
}
