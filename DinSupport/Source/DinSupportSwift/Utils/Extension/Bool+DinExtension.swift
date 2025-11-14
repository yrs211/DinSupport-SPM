//
//  Bool+DinExtension.swift
//  DinSupport
//
//  Created by Jin on 2021/5/13.
//

import Foundation

public extension Bool {
    func toString () -> String {
        if self {
            return "1"
        } else {
            return "0"
        }
    }

    func toInt () -> Int {
        if self {
            return 1
        } else {
            return 0
        }
    }
}
