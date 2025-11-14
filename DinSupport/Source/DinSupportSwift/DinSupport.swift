//
//  DinSupport.swift
//  DinSupport
//
//  Created by Jin on 2021/5/5.
//

import UIKit
import ZipArchive
//import SSZipArchive

public struct DinSupport {
    static var appID: String?
    static var appKey: String?
    static var appSecret: String?

    // 用于KCP通讯的地址和端口
    static var udpURL: String = ""
    static var udpPort: UInt16 = 0
    // 用于获取当前客户端公网地址和端口的服务器地址和端口
    static var getPublicIPHost: String = ""
    static var getPublicIPPort: UInt16 = 0

    public static func modifyUDP(url: String, port: UInt16, getPublicIPHost: String, getPublicIPPort: UInt16) {
        self.udpURL = url
        self.udpPort = port
        self.getPublicIPHost = getPublicIPHost
        self.getPublicIPPort = getPublicIPPort
    }

    public static func config(_ config: Config) {
        self.appID = config.appID
        self.appKey = config.appKey
        self.appSecret = config.appSecret
        self.udpURL = config.udpURL
        self.udpPort = config.udpPort
        self.getPublicIPHost = config.getPublicIPHost
        self.getPublicIPPort = config.getPublicIPPort
    }

    @available(iOS 15.0, *)
    public static func exportLog(in range: LogExportTimeRange) throws -> URL {

        let exporter = DinLogStoreExporter(subsystem: "DinsaferModules")

        let workingDirectory = FileManager.default.temporaryDirectory

        var logFile: DinLogStoreExporter.LogFile
        do {
            logFile = try exporter.export(to: workingDirectory, startDate: range.startDate, overrideIfNeeded: true)
        } catch { throw CreateLogfileFailure() }

        let ext = "zip"
        let zippedFilename = "\(logFile.name).\(ext)"
        let zippedFileURL: URL = {
            if #available(iOS 16.0, *) {
                return workingDirectory.appending(component: zippedFilename, directoryHint: .notDirectory)
            } else {
                return workingDirectory.appendingPathComponent(zippedFilename, isDirectory: false)
            }
        }()

        if !SSZipArchive.createZipFile(atPath: zippedFileURL.path, withFilesAtPaths: [logFile.url.path], withPassword: self.appSecret) {
            throw CreateLogfileFailure()
        }
        try? FileManager.default.removeItem(at: logFile.url)
        return zippedFileURL
    }

    public struct Config {
        let appID: String
        let appKey: String
        let appSecret: String
        let udpURL: String
        let udpPort: UInt16
        let getPublicIPHost: String
        let getPublicIPPort: UInt16

        public init(
            appID: String,
            appKey: String,
            appSecret: String,
            udpURL: String,
            udpPort: UInt16,
            getPublicIPHost: String,
            getPublicIPPort: UInt16
        ) {
            self.appID = appID
            self.appKey = appKey
            self.appSecret = appSecret
            self.udpURL = udpURL
            self.udpPort = udpPort
            self.getPublicIPHost = getPublicIPHost
            self.getPublicIPPort = getPublicIPPort
        }
    }
}

extension DinSupport {

    @available(iOS 15.0, *)
    public enum LogExportTimeRange {
        case short
        case medium
        case long

        var hours: Int {
            switch self {
            case .short: return 1
            case .medium: return 3
            case .long: return 7
            }
        }

        var startDate: Date {
            let secondsInADay = 24 * 60 * 60
            return Date().addingTimeInterval(TimeInterval(-hours * secondsInADay))
        }
    }

    @available(iOS 15.0, *)
    public struct CreateLogfileFailure: LocalizedError {
        public var errorDescription: String? { "Failed to create a log file" }
    }
}
