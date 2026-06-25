// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "better_player",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        // The library name uses "-" because the plugin name contains "_".
        .library(name: "better-player", targets: ["better_player"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/hyperoslo/Cache.git", .upToNextMajor(from: "6.0.0")),
        .package(url: "https://github.com/pinterest/PINCache.git", from: "3.0.3"),
        // GCDWebServer has no official SPM support (upstream is archived); use the
        // maintained Readium fork. It renames both the module and the classes with a
        // `Readium` prefix, so the shared Swift sources alias them back to the original
        // `GCDWebServer*` names under SWIFT_PACKAGE (see GCDWebServerCompat.swift).
        .package(url: "https://github.com/readium/GCDWebServer.git", from: "4.0.0"),
    ],
    targets: [
        // Objective-C target. This is the module Flutter imports; it exposes
        // `BetterPlayerPlugin`. Mixed-language targets are not allowed in SPM, so the
        // Swift code lives in the separate `better_player_cache` target below.
        .target(
            name: "better_player",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "better_player_cache",
            ]
        ),
        // Swift target: cache manager, caching player item and the vendored HLS reverse
        // proxy server (StyleShare/HLSCachingReverseProxyServer has a broken SPM manifest,
        // so its single source file is vendored here).
        .target(
            name: "better_player_cache",
            dependencies: [
                .product(name: "Cache", package: "Cache"),
                .product(name: "PINCache", package: "PINCache"),
                .product(name: "ReadiumGCDWebServer", package: "GCDWebServer"),
            ]
        ),
    ]
)
