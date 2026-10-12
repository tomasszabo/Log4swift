//
//  DateRotationPolicy.swift
//  Log4swift
//
//  Created by Jérôme Duquennoy on 20/08/2018.
//  Copyright © 2018 jerome. All rights reserved.
//

import Foundation

/**
 This rotation policy will request a rotation once a file gets older than a given threshold.
 */
final class DateRotationPolicy: FileAppenderRotationPolicy {
  /// The maximum age of the file in seconds before rotation is requested.
  private struct State {
    var maxFileAge: TimeInterval
    var creationDate: Date?
  }
  private let state: Synchronized<State>
  public var maxFileAge: TimeInterval {
    get { state.withValue { $0.maxFileAge } }
    set { state.withValue { $0.maxFileAge = newValue } }
  }
  internal var currentFileCreationCreationDate: Date? {
    get { state.withValue { $0.creationDate } }
    set { state.withValue { $0.creationDate = newValue } }
  }
  
  /// Creates a rotation policy with a max file age in seconds.
  init(maxFileAge: TimeInterval) {
    self.state = Synchronized(State(maxFileAge: maxFileAge))
  }
  
  func appenderDidOpenFile(atPath path: String) {
    loggingStateLock.lock()
    defer { loggingStateLock.unlock() }
    let fileManager = FileManager.default
    do {
      let fileAttributes = try fileManager.attributesOfItem(atPath: path)
      self.currentFileCreationCreationDate = fileAttributes[FileAttributeKey.creationDate] as? Date ?? Date()
    } catch {
      self.currentFileCreationCreationDate = Date()
    }
  }
  
  func appenderDidAppend(data: Data) {
  }
  
  func shouldRotate() -> Bool {
    loggingStateLock.lock()
    defer { loggingStateLock.unlock() }
    guard let fileDate = self.currentFileCreationCreationDate else { return false }
  
    return Date().timeIntervalSince(fileDate) >= self.maxFileAge
  }
}
