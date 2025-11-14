//
//  DinSupportLogger.swift
//  DinSupport
//
//  Created by AdrianHor on 2023/4/19.
//

#if ENABLE_LOG

import Foundation
import os.log

@available(iOS 14.0, *)
public typealias DinSupportLogger = Logger

@available(iOS 14.0, *)
public extension Logger {
    private static var subsystem = "DinsaferModules"
    static func loggerWithCategory(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}

#endif
