import Foundation
import XCTest
@testable import Log4swift

final class ConcurrencyTests: XCTestCase {
  func testSynchronousLoggingFromConcurrentThreadsDoesNotLoseMessages() {
    let appender = MemoryAppender()
    let logger = Logger(identifier: "concurrent", appenders: [appender])
    DispatchQueue.concurrentPerform(iterations: 1_000) { index in
      logger.info("message-\(index)")
    }
    XCTAssertEqual(appender.logMessages.count, 1_000)
    XCTAssertEqual(Set(appender.logMessages.map(\.message)).count, 1_000)
  }

  func testFactoryReturnsSameCachedLoggerDuringConcurrentLookup() {
    let factory = LoggerFactory()
    let results = Synchronized([Logger]())
    DispatchQueue.concurrentPerform(iterations: 500) { _ in
      let logger = factory.getLogger("test.child")
      results.withValue { $0.append(logger) }
    }
    let loggers = results.withValue { $0 }
    XCTAssertEqual(loggers.count, 500)
    XCTAssertTrue(loggers.allSatisfy { $0 === loggers[0] })
  }

  func testConcurrentAppenderArrayModificationIsAtomic() {
    let logger = Logger(identifier: "configuration")
    DispatchQueue.concurrentPerform(iterations: 200) { index in
      logger.appenders.append(MemoryAppender("appender-\(index)"))
    }
    XCTAssertEqual(logger.appenders.count, 200)
  }

  func testConcurrentFormattingAndPatternReconfiguration() throws {
    let formatter = try PatternFormatter(identifier: "pattern", pattern: "A %m")
    let output = Synchronized([String]())
    DispatchQueue.concurrentPerform(iterations: 1_000) { index in
      do {
        if index.isMultiple(of: 2) {
          try formatter.update(withDictionary: ["Pattern": "B %m"])
        } else {
          try formatter.update(withDictionary: ["Pattern": "A %m"])
        }
        let message = formatter.format(message: "message", info: [:])
        output.withValue { $0.append(message) }
      } catch {
        XCTFail("Pattern update failed: \(error)")
      }
    }
    XCTAssertEqual(output.withValue { $0.count }, 1_000)
    XCTAssertTrue(output.withValue { $0.allSatisfy { ["A message", "B message"].contains($0) } })
  }

  func testConcurrentLoggingAndDestinationReconfiguration() {
    let first = MemoryAppender()
    let second = MemoryAppender()
    let logger = Logger(identifier: "changing", appenders: [first])
    DispatchQueue.concurrentPerform(iterations: 1_000) { index in
      logger.appenders = index.isMultiple(of: 2) ? [first] : [second]
      logger.info("message-\(index)")
    }
    let messages = first.logMessages + second.logMessages
    XCTAssertEqual(messages.count, 1_000)
    XCTAssertEqual(Set(messages.map(\.message)).count, 1_000)
  }

  func testConcurrentFileWritesAndRotationRetainEveryMessage() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let appender = FileAppender(identifier: "file", filePath: directory.appendingPathComponent("log").path,
                                rotationPolicies: [SizeRotationPolicy(maxFileSize: 100)])
    let logger = Logger(identifier: "file", appenders: [appender])
    DispatchQueue.concurrentPerform(iterations: 200) { index in
      logger.info("message-\(index)")
    }
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    let messages = try files.flatMap {
      try String(contentsOf: $0, encoding: .utf8).split(separator: "\n").map(String.init)
    }
    XCTAssertGreaterThan(files.count, 1)
    XCTAssertEqual(messages.count, 200)
    XCTAssertEqual(Set(messages).count, 200)
  }

  func testDeferredClosuresPreserveOrderAndCallerThreadMetadata() throws {
    let completed = expectation(description: "All asynchronous messages")
    completed.expectedFulfillmentCount = 100
    let appender = CompletionAppender(completed: completed)
    appender.formatter = try PatternFormatter(identifier: "caller", pattern: "%t %m")
    let logger = Logger(identifier: "asynchronous", appenders: [appender])
    logger.asynchronous = true
    let callerThread = String(currentThreadId(), radix: 16)
    for index in 0..<100 {
      logger.info { "message-\(index)" }
    }
    wait(for: [completed], timeout: 5)
    XCTAssertEqual(appender.messages, (0..<100).map { "\(callerThread) message-\($0)" })
  }

  func testFactoryAutoReloadDoesNotRetainFactory() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    weak var factory: LoggerFactory?
    do {
      let value = LoggerFactory()
      factory = value
      try value.readConfiguration(fromPlistFile: path, autoReload: true)
    }
    XCTAssertNil(factory)
  }

  func testDeferredLogKeepsDestinationCapturedAtSubmission() {
    let started = expectation(description: "Deferred closure started")
    let completed = expectation(description: "Second message completed")
    let oldDestination = MemoryAppender()
    let newDestination = CompletionAppender(completed: completed)
    let logger = Logger(identifier: "snapshot", appenders: [oldDestination])
    logger.asynchronous = true
    let resume = DispatchSemaphore(value: 0)
    logger.info {
      started.fulfill()
      guard resume.wait(timeout: .now() + 5) == .success else {
        XCTFail("Deferred logging did not resume")
        return "timeout"
      }
      return "first"
    }
    wait(for: [started], timeout: 3)
    logger.appenders = [newDestination]
    logger.info("second")
    resume.signal()
    wait(for: [completed], timeout: 5)
    XCTAssertEqual(oldDestination.logMessages.map(\.message), ["first"])
    XCTAssertEqual(newDestination.messages, ["second"])
  }
}

private final class CompletionAppender: Appender, @unchecked Sendable {
  private let storage = Synchronized([String]())
  private let completed: XCTestExpectation?
  var messages: [String] { storage.withValue { $0 } }

  init(completed: XCTestExpectation) {
    self.completed = completed
    super.init("completion")
  }

  required init(_ identifier: String) {
    completed = nil
    super.init(identifier)
  }

  override func performLog(_ log: String, level: LogLevel, info: LogInfoDictionary) {
    storage.withValue { $0.append(log) }
    completed?.fulfill()
  }
}
