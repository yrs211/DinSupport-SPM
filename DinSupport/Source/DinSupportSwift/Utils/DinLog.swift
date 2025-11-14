//
//  DinLog.swift
//  DinSupport
//
//  Created by Lee on 2025/7/16.
//

import os.log
import UIKit
public struct DinLog {
    private static var defaultSubSystem = "DinsaferModules"
    
    private static var pool: [String: OSLog] = [:]
    private static let queue = DispatchQueue(label: DinSupportQueueName.log)
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()
    
    /// 修改日志的 subsystem
    /// - Parameter subsystem: 新的子系统名称
    /// @Discussion
    /// 修改 subsystem 会影响到 DinLogStoreExporter 的导出逻辑，在使用后者时请注意调整
    public static func configure(subsystem: String) {
        defaultSubSystem = subsystem
    }
    
    public static func log(_ level: Level,
                           _ message: @autoclosure () -> Any,
                           subsystem: String? = nil,
                           category: Category = .default,
                           file: String = #file, function: String = #function, line: Int = #line,
                           privacy: Privacy = .public) {
#if ENABLE_LOG
        let addtionalInfo = "\(dateFormatter.string(from: Date())) [\((file as NSString).lastPathComponent):\(line)] \(function)"
        let logMessage = "\(message())"
        let logger = logger(for: subsystem ?? defaultSubSystem, category: category.name)
        
        if #available(iOS 14.0, *) {
            // ???: 直接传 privacy.osPrivacy 的值会报错 Argument must be a static method or property of 'OSLogPrivacy'
            if privacy == .public {
                Logger(logger).log(level: level.osLevel, "\(addtionalInfo, privacy: .public) \(logMessage, privacy: .public)")
            } else {
                Logger(logger).log(level: level.osLevel, "\(addtionalInfo, privacy: .public) \(logMessage, privacy: .private)")
            }
        } else if #available(iOS 12.0, *) {
            if privacy == .public {
                os_log(level.osLevel, log: logger, "%{public}@ %{public}@", addtionalInfo, logMessage)
            } else {
                os_log(level.osLevel, log: logger, "%{public}@ %{private}@", addtionalInfo, logMessage)
            }
        } else {
            NSLog("\(level)" + "[\(subsystem ?? defaultSubSystem):\(category.name)] " + addtionalInfo + " " + (privacy == .public ? logMessage : "<private>"))
        }
#endif
    }
    
    private static func logger(for subsystem: String, category: String) -> OSLog {
        let key = "\(subsystem).\(category)"
        return queue.sync {
            if let cached = pool[key] { return cached }
            let new = OSLog(subsystem: subsystem, category: category)
            pool[key] = new
            return new
        }
    }
    
    public enum Level: CustomStringConvertible {
        case info, debug, error
        
        var osLevel: OSLogType {
            switch self {
            case .info: return .info
            case .debug: return .debug
            case .error: return .error
            }
        }
        
        public var description: String {
            switch self {
            case .info: return "[INFO]"
            case .debug: return "[DEBUG]"
            case .error: return "[ERROR]"
            }
        }
    }
    
    public enum Privacy {
        case `public`, `private`
        
        @available(iOS 14.0, *)
        var osPrivacy: OSLogPrivacy {
            switch self {
            case .public: return OSLogPrivacy.public
            case .private: return OSLogPrivacy.private
            }
        }
    }
    
    public enum Category {
        case `default`, ui, network, database, custom(String)
        
        var name: String {
            switch self {
            case .default: return "Default"
            case .ui: return "UI"
            case .network: return "Network"
            case .database: return "Database"
            case .custom(let name): return name
            }
        }
    }
}

// MARK: - Convenient methods
extension DinLog {
    public static func log(_ message: @autoclosure () -> Any,
                            subsystem: String? = nil,
                            category: Category = .default,
                            file: String = #file, function: String = #function, line: Int = #line,
                            privacy: Privacy = .public) {
        log(.info, message(), subsystem: subsystem, category: category, file: file, function: function, line: line, privacy: privacy)
    }
    
    public static func info(_ message: @autoclosure () -> Any,
                            subsystem: String? = nil,
                            category: Category = .default,
                            file: String = #file, function: String = #function, line: Int = #line,
                            privacy: Privacy = .public) {
        log(.info, message(), subsystem: subsystem, category: category, file: file, function: function, line: line, privacy: privacy)
    }
    
    public static func debug(_ message: @autoclosure () -> Any,
                            subsystem: String? = nil,
                            category: Category = .default,
                            file: String = #file, function: String = #function, line: Int = #line,
                            privacy: Privacy = .public) {
        log(.debug, message(), subsystem: subsystem, category: category, file: file, function: function, line: line, privacy: privacy)
    }
    
    public static func error(_ message: @autoclosure () -> Any,
                            subsystem: String? = nil,
                            category: Category = .default,
                            file: String = #file, function: String = #function, line: Int = #line,
                            privacy: Privacy = .public) {
        log(.error, message(), subsystem: subsystem, category: category, file: file, function: function, line: line, privacy: privacy)
    }
}
