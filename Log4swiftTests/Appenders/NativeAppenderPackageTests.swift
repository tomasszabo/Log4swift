// Licensed under the Apache License, Version 2.0. See LICENSE.

#if SWIFT_PACKAGE
import XCTest
@testable import Log4swift

final class NativeAppenderPackageTests: XCTestCase {
  func testASLWrapperRemainsAvailableThroughLog4swiftImport() {
    let appender = ASLAppender("asl")
    XCTAssertTrue(type(of: appender.aslClient) == ASLWrapper.self)
  }

  func testSystemAppenderUsesUnifiedLogging() {
    let appender = SystemAppender("system")
    XCTAssertTrue(appender.backendAppender is AppleUnifiedLoggerAppender)
  }

  func testNativeAppendersAreAvailableToConfigurationFactory() {
    let appenderTypes = Appender.availableAppenderTypes
    XCTAssertTrue(appenderTypes.contains { $0 == ASLAppender.self })
    XCTAssertTrue(appenderTypes.contains { $0 == AppleUnifiedLoggerAppender.self })
    #if !os(watchOS)
    XCTAssertTrue(appenderTypes.contains { $0 == NSLoggerAppender.self })
    #endif
  }

  #if !os(watchOS)
  func testNSLoggerClientIsLinkedWithoutStartingNetworkDiscovery() {
    let appender = NSLoggerAppender("nslogger")
    let defaultOptions = UInt32(kLoggerOption_BufferLogsUntilConnection)
      | UInt32(kLoggerOption_BrowseBonjour)
      | UInt32(kLoggerOption_BrowseOnlyLocalDomain)
      | UInt32(kLoggerOption_UseSSL)
      | UInt32(kLoggerOption_CaptureSystemConsole)
    XCTAssertEqual(appender.logger.pointee.options, defaultOptions)
  }
  #endif
}
#endif
