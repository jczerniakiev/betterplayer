// Swift Package Manager compatibility shim.
//
// The CocoaPods build links the original `GCDWebServer` pod, whose classes are named
// `GCDWebServer`, `GCDWebServerRequest`, etc. SPM has no official GCDWebServer package, so
// the Package.swift uses the Readium fork (`ReadiumGCDWebServer`), which prefixes every
// class with `Readium`. These module-internal type aliases map the prefixed names back to
// the originals so the shared sources (CacheManager.swift, HLSCachingReverseProxyServer.swift)
// compile unchanged under both build systems.
#if SWIFT_PACKAGE
import ReadiumGCDWebServer

// These are `public` because the vendored HLSCachingReverseProxyServer exposes them in its
// public API (e.g. `public init(webServer: GCDWebServer, ...)`); an internal alias would
// make that API "use an internal type".
public typealias GCDWebServer = ReadiumGCDWebServer
public typealias GCDWebServerRequest = ReadiumGCDWebServerRequest
public typealias GCDWebServerDataResponse = ReadiumGCDWebServerDataResponse
public typealias GCDWebServerErrorResponse = ReadiumGCDWebServerErrorResponse
#endif
