//
//  DinP2PDeliver.swift
//  DinSupport
//
//  Created by Jin on 2021/8/7.
//

import UIKit

class DinP2PDeliver: DinDeliver {
    override func connectToDestination(include ipAdress: String, port: UInt16) {
        // 重写，抛弃DinDeliver上面的逻辑
        // p2p 需要用同一个Socket对象，所以Socket不需要释放
        modify(ipAdress: ipAdress, port: port)
        if socket == nil {
            self.connect()
        } else {
            startKeepLive()
        }
    }
}
