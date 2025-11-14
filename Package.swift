// swift-tools-version: 5.9
import PackageDescription 

let package = Package(
    name: "DinSupport",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "DinSupport",
            type: .dynamic,
            targets: ["DinSupportSwift"]  // 👉 关键：改为 Swift Target 名（之前写的 "DinSupport" 不存在）
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ZipArchive/ZipArchive.git", from: "2.4.3"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from:"1.8.4"),
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket.git", from:"7.6.5")
     ],
    targets: [
        // 纯 Objective-C Target（参数顺序完全正确）
        .target(
            name: "DinSupportObjC",
            dependencies: [],
            path: "DinSupport/Source/DinSupportObjC",
            sources: ["."],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
                .define("SWIFT_PACKAGE")
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CFNetwork")
            ]
        ),
        
        // 纯 Swift Target（终极正确顺序：name → dependencies → path → sources → linkerSettings）
        .target(
            name: "DinSupportSwift",
            dependencies: [
                .target(name: "DinSupportObjC"),
                .product(name: "ZipArchive", package: "ZipArchive"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket")
            ],
            path: "DinSupport/Source/DinSupportSwift",  // 1. path 在前
            sources: ["."],           // 2. sources 在后（必须在 path 之后）
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit")
            ]
        )
    ]
)
