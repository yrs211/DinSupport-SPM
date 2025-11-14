//
//  DinAccessory.swift
//  DinSupport
//
//  Created by Jin on 2021/4/24.
//

import UIKit
import DinSupportObjC
public enum DinAccessoryType: Int {
    case security = 0
    case remoteControll = 1
    case camera = 2
    case smartPlug = 3
    case siren = 4
    case smokeSensor = 5
    case gasSensor = 6
    case wirelessKeypad = 7
    case panicButton = 8
    case newASK = 10
    case thirdParty = 20
    case smartBtn = 21
    case signalRepeaterPlug = 160
}

public struct DinAccessory {
    /// 通过socket返回电量或开关状态的配件
    public static var needRecieveStatusPluginsType: [String] = ["11", "25", "2C", "2F", "3D", "34", "35", "36", "38", "39", "3A", "3B", "3C", "4A"]
    /// 显示信号量的配件
    public static let showSignalPlugins = ["2C", "2F", "3D", "34", "35", "36", "38", "39", "3A", "3B", "3C", "4A"]
    /// 显示开合状态的配件
    public static let showApartStatusPlugins = ["11", "1C", "25", "3D", "38"]
    /// 显示电量的配件
    public static let showBatteryLevelPlugins = ["2C", "2F", "3D", "34", "35", "36", "38", "39", "3A", "3B", "3C", "4A"]
    /// 显示防拆的配件
    public static let showTamperPlugins = ["2C", "2F", "3D", "34", "35", "36", "38", "39", "4A"]
    /// 有chime功能的配件
    public static let chimePlugins = ["2C", "3D", "36", "38", "4A"]
    /// 五键自定义遥控器
    public static let customRemoteControl = ["3A"]
    /// 旧门磁
    public static let oldDoorWindowsStypes = ["0B", "06"]
    /// 新门磁
    public static let askDoorWindowsStypes = ["11", "1C", "2C", "16", "25", "3D", "38"]
    /// 旧插座
    public static let oldSmartPlugStypes = ["15"]
    /// 新智能插座+中继信号插座
    public static let askSmartPlugStypes = ["3E", "4E"]
    /// 新智能插座
    public static let smartPlugStypes = ["3E"]
    /// 中继信号插座
    public static let signalRepeaterPlugStypes = ["4E"]
    /// 有心跳功能的插座
    public static let keepliveSmartPlugStypes = ["3E", "4E"]

    /// 支持门磁推送
    public static let supportSettingDoorWindowPushStatusTypes = ["38", "3D"]
    /// 支持调节灵敏度
    public static let supportSettingSensitivityTypes = ["4A"]

    /// 检查大type
    public static func checkDType(_ dType: String) -> Bool {
        let regex = "[0123456789]"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: dType)
    }

    /// 检查小type
    public static func checkStype(_ sType: String) -> Bool {
        ["0B", "16", "1C", "11", "25", "38", "3D", "09", "17", "24", "36", "0A", "05", "2D", "3C", "06", "19", "2C", "07", "23", "0E", "18", "2E", "39", "08", "04", "02", "01", "0D", "1E", "3A", "37", "1F", "15", "3E", "14", "21", "22", "34", "35", "30", "31", "1B", "2F", "32", "33", "12", "3B", "4A", "4E"].contains(sType)
    }

    public static func pluginID(isASKPlugin pluginID: String, decodeID: String) -> Bool {
        pluginID.contains("!") && (decodeID.count < 1)
    }

    /// 默认官方配件功能名字 [TypeID: Names]
    public static func supportedTypeNames() -> [String: String] {
        ["0B": "Door Window Sensor",
         "16": "Door Window Sensor",
         "1C": "Door Window Sensor",
         "11": "Door Window Sensor",
         "25": "Door Window Sensor",
         "38": "Door Window Sensor",
         "3D": "Rolling Door Window Sensor",
         "09": "PIR Sensor",
         "17": "PIR Sensor",
         "24": "PIR Sensor",
         "36": "PIR Sensor",
         "4A": "PIR Sensor",
         "0A": "Gas Sensor",
         "05": "Smoke Sensor",
         "2D": "Smoke Sensor",
         "3C": "Smoke Sensor",
         "06": "Vibration Sensor",
         "19": "Vibration Sensor",
         "2C": "Vibration Sensor",
         "07": "Panic Button",
         "23": "Panic Button",
         "0E": "Liquid Sensor",
         "18": "Liquid Sensor",
         "2E": "Liquid Sensor",
         "39": "Liquid Sensor",
         "08": "Remote Controller",
         "04": "Remote Controller",
         "02": "Remote Controller",
         "01": "Remote Controller",
         "0D": "Remote Controller",
         "1E": "Remote Controller",
         "3A": "Remote Controller",
         "37": "RFID Tag",
         "1F": "IP Camera",
         "15": "Smart Plug",
         "3E": "Smart Plug",
         "14": "Wireless Siren",
         "21": "Wireless Siren",
         "22": "Wireless Siren",
         "34": "Wireless Siren",
         "35": "Wireless Siren",
         "30": "Smoke Sensor",
         "31": "CO Detector",
         "1B": "Wireless Keypad",
         "2F": "Wireless Keypad",
         "32": "Outdoor PIR",
         "33": "Outdoor Beam",
         "12": "Roller Shutter",
         "3B": "Smart Button"]
    }

    static func isKeypad(pluginID: String, decodeID: String?) -> Bool {
        var dinID = ""
        if let did = decodeID, did.count > 0 {
            dinID = did
        } else {
            dinID = DinAccessoryUtil.str64(toHexStr: pluginID) 
        }
        let dType = dinID[0...0]
        let sType = dinID[1...2]
        if dType == "7" {
            return true
        } else if sType == "1B" || sType == "2F" {
            return true
        } else if sType == "37" {
            // RFID tag
            return true
        }
        else {
            return false
        }
    }
}
