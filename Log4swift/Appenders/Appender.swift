//
//  Appender.swift
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
Appenders are responsible for sending logs to heir destination.
This class is the base class, from which all appenders should inherit.
*/
// Open classes cannot have checked Sendable conformance. Subclasses must keep
// mutable state synchronized, including direct performLog/update calls.
@objc open class Appender: NSObject, @unchecked Sendable {
  public enum DictionaryKey: String {
    case ThresholdLevel = "ThresholdLevel"
    case FormatterId = "FormatterId"
  }
  
  @objc let identifier: String
  private struct State {
    var thresholdLevel = LogLevel.Debug
    var formatter: Formatter?
  }
  private let state = Synchronized(State())
  @objc public var thresholdLevel: LogLevel {
    get { state.withValue { $0.thresholdLevel } }
    set { state.withValue { $0.thresholdLevel = newValue } }
  }
  public var formatter: Formatter? {
    get { state.withValue { $0.formatter } }
    set { state.withValue { $0.formatter = newValue } }
  }
  
  @objc
  public required init(_ identifier: String) {
    self.identifier = identifier
  }

  /// Protect custom mutable state, including property access and direct
  /// performLog/update calls. Do not wait for other threads inside this block.
  public final func withSynchronization<Result>(_ body: () throws -> Result) rethrows -> Result {
    try withLoggingLock(body)
  }
  
  open func update(withDictionary dictionary: Dictionary<String, Any>, availableFormatters: Array<Formatter>) throws {
    loggingStateLock.lock()
    defer { loggingStateLock.unlock() }
     if let safeThresholdString = (dictionary[DictionaryKey.ThresholdLevel.rawValue] as? String) {
      if let safeThreshold = LogLevel(safeThresholdString) {
        thresholdLevel = safeThreshold
      } else {
        throw NSError.Log4swiftError(description: "Invalid '\(DictionaryKey.ThresholdLevel.rawValue)' for appender '\(self.identifier)'")
      }
    }
    
    if let safeFormatterId = (dictionary[DictionaryKey.FormatterId.rawValue] as? String) {
      if let formatter = availableFormatters.find(filter: { $0.identifier == safeFormatterId }) {
        self.formatter = formatter
      } else {
        throw NSError.Log4swiftError(description: "No such formatter '\(safeFormatterId)' for appender \(self.identifier)")
      }
    }
  }
  
  open func performLog(_ log: String, level: LogLevel, info: LogInfoDictionary) {
    // To be overriden by subclasses
  }
  
  final func log(_ log: String, level: LogLevel, info: LogInfoDictionary) {
    loggingStateLock.lock()
    defer { loggingStateLock.unlock() }
    if(level.rawValue >= self.thresholdLevel.rawValue) {
      let logMessage: String
      
      if let formatter = self.formatter {
        logMessage = formatter.format(message: log, info: info)
      } else {
        logMessage = log
      }
      
      self.performLog(logMessage, level: level, info: info)
    }
  }
}

fileprivate struct AppenderSubclassEnumerator {
  static let availableAppenderTypes: [Appender.Type] = getAvailableAppenderTypes
  
  static private var getAvailableAppenderTypes: [Appender.Type] {
    let motherClassInfo = ClassInfo(Appender.self)
    
    let result = motherClassInfo.subclasses.map {
      return $0.classObject as! Appender.Type
    }
    
    return result
  }
}

extension Appender {
  static var availableAppenderTypes: [Appender.Type] {
    return AppenderSubclassEnumerator.availableAppenderTypes
  }
}
