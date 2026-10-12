//
//  Logger.swift
//  log4swift
//
//  Created by Jérôme Duquennoy on 14/06/2015.
//  Copyright © 2015 Jérôme Duquennoy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

/**
A logger is identified by a UTI identifier, it defines a threshold level and a destination appender
*/
@objc public final class Logger: NSObject, Sendable {
  public enum DictionaryKey: String {
    case ThresholdLevel = "ThresholdLevel"
    case AppenderIds = "AppenderIds"
    case Asynchronous = "Asynchronous"
  }
  
  private static let loggingQueue:DispatchQueue = {
    let createdQueue: DispatchQueue
    
    if #available(OSX 10.10, *) {
      createdQueue = DispatchQueue(label: "log4swift.dispatchLoggingQueue", qos: .background, attributes: []) //(label: "log4swift.dispatchLoggingQueue", attributes: [.serial, .background])
    } else {
      let backgroundQueue = DispatchQueue.global(priority: .background)
      createdQueue = DispatchQueue(label: "log4swift.dispatchLoggingQueue", attributes: [], target: backgroundQueue)
    }
    return createdQueue
  }()
  
  /// The UTI string that identifies the logger. Example : product.module.feature
  public let identifier: String
  
  private struct State {
    var parent: Logger?
    var thresholdLevel: LogLevel
    var appenders: [Appender]
    var asynchronous = false
  }
  private let state: Synchronized<State>

  internal var parent: Logger? {
    get { state.withValue { $0.parent } }
    set { state.withValue { $0.parent = newValue } }
  }

  /// If asynchronous is true, only the minimum of work will be done on the main thread, the rest will be deffered to a low priority background thread.
  /// The order of the messages will be preserved in async mode.
  @objc
  public var asynchronous: Bool {
    get {
      state.withValue { state in
        state.parent?.asynchronous ?? state.asynchronous
      }
    }
    set {
      withLoggingLock {
        self.breakDependencyWithParent()
        state.withValue { $0.asynchronous = newValue }
      }
    }
  }
  
  /// The threshold under which log messages will be ignored.
  /// For example, if the threshold is Warning:
  /// * logs issued with a Debug or Info will be ignored
  /// * logs issued wiht a Warning, Error or Fatal level will be processed
  @objc
  public var thresholdLevel: LogLevel {
    get {
      state.withValue { state in
        state.parent?.thresholdLevel ?? state.thresholdLevel
      }
    }
    set {
      withLoggingLock {
        self.breakDependencyWithParent()
        state.withValue { $0.thresholdLevel = newValue }
      }
    }
  }

  /// The list of destination appenders for the log messages.
  @objc
  public var appenders: [Appender] {
    get {
      state.withValue { state in
        state.parent?.appenders ?? state.appenders
      }
    }
    set {
      withLoggingLock {
        self.breakDependencyWithParent()
        state.withValue { $0.appenders = newValue }
      }
    }
    _modify {
      loggingStateLock.lock()
      defer { loggingStateLock.unlock() }
      var value = self.appenders
      defer { self.appenders = value }
      yield &value
    }
  }

  
  /// Creates a new logger with the given identifier, log level and appenders.
  /// The identifier will not be modifiable, and should not be an empty string.
  @objc
  public init(identifier: String, level: LogLevel = LogLevel.Debug, appenders: [Appender] = []) {
    self.identifier = identifier
    self.state = Synchronized(State(thresholdLevel: level, appenders: appenders))
  }

  @objc
  convenience override init() {
    self.init(identifier: "", appenders: Logger.createDefaultAppenders())
  }
  
  /// Create a logger that is a child of the given logger.
  /// The created logger will follow the parent logger's configuration until it is manually modified.
  @objc
  public convenience init(parentLogger: Logger, identifier: String) {
    loggingStateLock.lock()
    defer { loggingStateLock.unlock() }
    self.init(identifier: identifier, level: parentLogger.thresholdLevel, appenders: [Appender]() + parentLogger.appenders)
    self.parent = parentLogger
  }
  
  /// Updates the logger with the content of the configuration dictionary.
  internal func update(withDictionary dictionary: Dictionary<String, Any>, availableAppenders: Array<Appender>) throws {
    loggingStateLock.lock()
    defer { loggingStateLock.unlock() }
    breakDependencyWithParent()
    
    if let safeLevelString = dictionary[DictionaryKey.ThresholdLevel.rawValue] as? String {
      if let safeLevel = LogLevel(safeLevelString) {
        self.thresholdLevel = safeLevel
      } else {
				throw NSError.Log4swiftError(description: "Invalid '\(DictionaryKey.ThresholdLevel.rawValue)' value for logger '\(self.identifier)'")
      }
    }
    
    if let appenderIds = dictionary[DictionaryKey.AppenderIds.rawValue] as? Array<String> {
      var selectedAppenders = [Appender]()
      for currentAppenderId in appenderIds {
				if let foundAppender = availableAppenders.find(filter: {$0.identifier == currentAppenderId}) {
          selectedAppenders.append(foundAppender)
        } else {
          throw NSError.Log4swiftError(description: "No such appender '\(currentAppenderId)' for logger \(self.identifier)")
        }
      }
      self.appenders = selectedAppenders
    }
    
    if let asynchronous = dictionary[DictionaryKey.Asynchronous.rawValue] as? Bool {
      self.asynchronous = asynchronous
    }
  }
  
  func resetConfiguration() {
    loggingStateLock.lock()
    defer { loggingStateLock.unlock() }
    self.thresholdLevel = .Debug
    self.appenders = Logger.createDefaultAppenders()
    self.asynchronous = false
  }
  
  // MARK: Logging methods

  /// Logs the provided message with a trace level.
  @nonobjc public func trace(_ format: String, _ args: CVarArg..., file: String = #file, line: Int = #line, function: String = #function) {
		let formattedMessage = format.format(args: args)
		self.log(message: formattedMessage, level: LogLevel.Trace, file: file, line: line, function: function)
  }
  /// Logs the provided message with a debug level.
  @nonobjc public func debug(_ format: String, _ args: CVarArg..., file: String = #file, line: Int = #line, function: String = #function) {
    let formattedMessage = format.format(args: args)
    self.log(message: formattedMessage, level: LogLevel.Debug, file: file, line: line, function: function)
  }
  /// Logs the provided message with an info level
  @nonobjc public func info(_ format: String, _ args: CVarArg..., file: String = #file, line: Int = #line, function: String = #function) {
    let formattedMessage = format.format(args: args)
    self.log(message: formattedMessage, level: LogLevel.Info, file: file, line: line, function: function)
  }
  /// Logs the provided message with a warning level
  @nonobjc public func warning(_ format: String, _ args: CVarArg..., file: String = #file, line: Int = #line, function: String = #function) {
    let formattedMessage = format.format(args: args)
    self.log(message: formattedMessage, level: LogLevel.Warning, file: file, line: line, function: function)
  }
  /// Logs the provided message with an error level
  @nonobjc public func error(_ format: String, _ args: CVarArg..., file: String = #file, line: Int = #line, function: String = #function) {
    let formattedMessage = format.format(args: args)
    self.log(message: formattedMessage, level: LogLevel.Error, file: file, line: line, function: function)
  }
  /// Logs the provided message with a fatal level
  @nonobjc public func fatal(_ format: String, _ args: CVarArg..., file: String = #file, line: Int = #line, function: String = #function) {
    let formattedMessage = format.format(args: args)
    self.log(message: formattedMessage, level: LogLevel.Fatal, file: file, line: line, function: function)
  }

  /// Logs a the message returned by the closure with a debug level
  /// If the logger's or appender's configuration prevents the message to be issued, the closure will not be called.
  @nonobjc public func trace(file: String = #file, line: Int = #line, function: String = #function, closure: @escaping @Sendable () -> String) {
		self.log(closure: closure, level: LogLevel.Trace, file: file, line: line, function: function)
  }
  /// Logs a the message returned by the closure with a debug level
  /// If the logger's or appender's configuration prevents the message to be issued, the closure will not be called.
  @nonobjc public func debug(file: String = #file, line: Int = #line, function: String = #function, closure: @escaping @Sendable () -> String) {
    self.log(closure: closure, level: LogLevel.Debug, file: file, line: line, function: function)
  }
  /// Logs a the message returned by the closure with an info level
  /// If the logger's or appender's configuration prevents the message to be issued, the closure will not be called.
  @nonobjc public func info(file: String = #file, line: Int = #line, function: String = #function, closure: @escaping @Sendable () -> String) {
    self.log(closure: closure, level: LogLevel.Info, file: file, line: line, function: function)
  }
  /// Logs a the message returned by the closure with a warning level
  /// If the logger's or appender's configuration prevents the message to be issued, the closure will not be called.
  @nonobjc public func warning(file: String = #file, line: Int = #line, function: String = #function, closure: @escaping @Sendable () -> String) {
    self.log(closure: closure, level: LogLevel.Warning, file: file, line: line, function: function)
  }
  /// Logs a the message returned by the closure with an error level
  /// If the logger's or appender's configuration prevents the message to be issued, the closure will not be called.
  @nonobjc public func error(file: String = #file, line: Int = #line, function: String = #function, closure: @escaping @Sendable () -> String) {
    self.log(closure: closure, level: LogLevel.Error, file: file, line: line, function: function)
  }
  /// Logs a the message returned by the closure with a fatal level
  /// If the logger's or appender's configuration prevents the message to be issued, the closure will not be called.
  @nonobjc public func fatal(file: String = #file, line: Int = #line, function: String = #function, closure: @escaping @Sendable () -> String) {
    self.log(closure: closure, level: LogLevel.Fatal, file: file, line: line, function: function)
  }
  
  /// Returns true if a message sent with the given level will be issued by at least one appender.
  public func willIssueLogForLevel(_ level: LogLevel) -> Bool {
    return withLoggingLock {
      level.rawValue >= self.thresholdLevel.rawValue && self.appenders.contains {
        level.rawValue >= $0.thresholdLevel.rawValue
      }
    }
  }
  
  @nonobjc internal func log(message: String, level: LogLevel, file: String? = nil, line: Int? = nil, function: String? = nil) {
    if let configuration = configurationForLog(level) {
      var info: LogInfoDictionary = [
        .LoggerName: self.identifier,
        .LogLevel: level,
        .Timestamp: NSDate().timeIntervalSince1970,
        .ThreadId: currentThreadId(),
        .ThreadName: currentThreadName()
      ]
      if let file = file {
        info[.FileName] = file
      }
      if let line = line {
        info[.FileLine] = line
      }
      if let function = function {
        info[.Function] = function
      }

      let appenders = configuration.appenders
      let metadata = info
      let logClosure: @Sendable () -> Void = {
        for currentAppender in appenders {
					currentAppender.log(message, level:level, info: metadata)
        }
      }

      self.executeLogClosure(logClosure, asynchronously: configuration.asynchronous)
    }
  }
  
  @nonobjc internal func log(closure: @escaping @Sendable () -> (String), level: LogLevel, file: String? = nil, line: Int? = nil, function: String? = nil) {
    if let configuration = configurationForLog(level) {
      var info: LogInfoDictionary = [
        .LoggerName: self.identifier,
        .LogLevel: level,
        .Timestamp: NSDate().timeIntervalSince1970,
        .ThreadId: currentThreadId(),
        .ThreadName: currentThreadName()
      ]
      if let file = file {
        info[.FileName] = file
      }
      if let line = line {
        info[.FileLine] = line
      }
      if let function = function {
        info[.Function] = function
      }

      let appenders = configuration.appenders
      let metadata = info
      let logClosure: @Sendable () -> Void = {
        let logMessage = closure()
        for currentAppender in appenders {
					currentAppender.log(logMessage, level:level, info: metadata)
        }
      }
      self.executeLogClosure(logClosure, asynchronously: configuration.asynchronous)
    }
  }
  
  // MARK: Private methods
  private func configurationForLog(_ level: LogLevel) -> (appenders: [Appender], asynchronous: Bool)? {
    withLoggingLock {
      guard willIssueLogForLevel(level) else { return nil }
      return (appenders, asynchronous)
    }
  }

  private func executeLogClosure(_ logClosure: @escaping @Sendable () -> (), asynchronously: Bool) {
    if asynchronously {
      Logger.loggingQueue.async(execute: logClosure)
    } else {
      logClosure()
    }
  }
  
  private func breakDependencyWithParent() {
    guard let parent = self.parent else {
      return
    }
    state.withValue {
      $0.thresholdLevel = parent.thresholdLevel
      $0.appenders = parent.appenders
      $0.asynchronous = parent.asynchronous
      $0.parent = nil
    }
  }

  private final class func createDefaultAppenders() -> [Appender] {
    return [StdOutAppender("defaultAppender")]
  }
}

/// returns the current thread name
private func currentThreadName() -> String {
  if Thread.isMainThread {
    return "main"
  } else {
    var name: String = Thread.current.name ?? ""
    if name.isEmpty {
      let queueNameBytes = __dispatch_queue_get_label(nil)
      if let queuName = String(validatingCString: queueNameBytes) {
        name = queuName
      }
    }
    if name.isEmpty {
      name = String(format: "%p", Thread.current)
    }
    
    return name
  }
}

internal func currentThreadId() -> UInt64 {
  var threadId: UInt64 = 0
  if (pthread_threadid_np(nil, &threadId) != 0) {
    threadId = UInt64(pthread_mach_thread_np(pthread_self()));
  }
  return threadId
}
