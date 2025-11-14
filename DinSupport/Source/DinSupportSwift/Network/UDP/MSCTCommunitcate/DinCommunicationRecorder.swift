//
//  DinCommunicationRecorder.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit

/// 记录收到并且正在处理或者已经处理的通讯包
/// 每个通讯Communicator都持有一个Recorder来记录，如果有重复的messageID，提示重复
class DinCommunicationRecorder: NSObject {
    /// 数据的读写队列
    static let queue = DispatchQueue(label: DinSupportQueueName.recordsQueue, attributes: .concurrent)
    /// 记录数组【不能直接使用，需要搭配queue来读写以达到线程安全】
    private var unsafeRecords = [DinCommunicationRecord]()

    /// 安全获取记录
    private var records: [DinCommunicationRecord] {
        var copyRecords = [DinCommunicationRecord]()
        DinCommunicationRecorder.queue.sync { [weak self] in
            if let self = self {
                copyRecords = self.unsafeRecords
            }
        }
        return copyRecords
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handlePackageCompleted(_:)),
                                               name: .dinMSCTPackCompleted,
                                               object: nil)
    }
}

extension DinCommunicationRecorder {
    @objc private func handlePackageCompleted(_ nofitication: Notification) {
        if let userinfo = nofitication.userInfo,
            let result = userinfo[DinSupportNotificationKey.dinMSCTResultKey] as? DinMSCTResult {
            for record in records {
                if record.crID == DinCommunicationRecord.getCommunicationRecordID(with: result.messageID, type: result.type) {
                    record.state = .received
                    break
                }
            }
        }
    }

    public func shouldAbandonMSCT(_ msct: MSCT) -> Bool {
        // 如果没有messageID则放行，后面的逻辑会处理
        let messageID = msct.messageID()
        guard messageID.count > 0 else {
            return false
        }

        // 是否存在对应的Communication记录
        var recordExist = false
        for record in records where record.crID == DinCommunicationRecord.getCommunicationRecordID(with: msct.messageID(), type: msct.header.msgType) {
            if record.state == .received {
                // 如果记录存在并且Communication是处于接收完毕的状态, 则通知抛弃
                return true
            }
            recordExist = true
        }
        if !recordExist {
            DinCommunicationRecorder.queue.async(flags: .barrier) { [weak self] in
                // 如果不存在则记录Communication
                let record = DinCommunicationRecord(with: msct)
                record.delegate = self
                self?.unsafeRecords.append(record)
            }
        }

        // 检查不到已经记录同时处于接收完毕的状态的Communication，不予抛弃
        return false
    }

    public func emptyRecords() {
        DinCommunicationRecorder.queue.async(flags: .barrier) { [weak self] in
            self?.unsafeRecords.removeAll()
        }
    }
}

extension DinCommunicationRecorder: DinCommunicationRecordDelegate {
    func recordExpire(_ record: DinCommunicationRecord) {
        DinCommunicationRecorder.queue.async(flags: .barrier) { [weak self] in
            if let theIndex = self?.unsafeRecords.firstIndex(where: { $0.crID == record.crID }) {
                self?.unsafeRecords.remove(at: theIndex)
            }
        }
    }
}
