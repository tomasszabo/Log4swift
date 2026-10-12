//
//  SubclassingTests.swift
//  Log4swift
//
//  Created by Igor Makarov on 03/01/2017.
//  Copyright © 2017 jerome. All rights reserved.
//

import XCTest
// do not import as @testable, we're testing subclassing from outside the module
import Log4swift

class DummyAppender: Log4swift.Appender, @unchecked Sendable {
  private var count = 0
  var performedCount: Int { withSynchronization { count } }

  override func update(withDictionary dictionary: Dictionary<String, Any>, availableFormatters: Array<Log4swift.Formatter>) throws {
    try super.update(withDictionary: dictionary, availableFormatters: availableFormatters)

  }
  open override func performLog(_ log: String, level: LogLevel, info: LogInfoDictionary) {
    withSynchronization { count += 1 }
  }
}

class SubclassingTests: XCTestCase {
  func testSubclassing() {
    let dummyAppender = DummyAppender("dummy")
    XCTAssertNotNil(dummyAppender)
  }

  func testCustomAppenderCanSynchronizeDirectConcurrentCalls() {
    let appender = DummyAppender("custom")
    DispatchQueue.concurrentPerform(iterations: 500) { _ in
      appender.performLog("message", level: .Info, info: [:])
    }
    XCTAssertEqual(appender.performedCount, 500)
  }
}
