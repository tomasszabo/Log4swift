//
//  SizeRotationPolicy.swift
//  Log4swift
//
//  Created by Jérôme Duquennoy on 20/08/2018.
//  Copyright © 2018 jerome. All rights reserved.
//

import Foundation

/**
 This rotation policy will request a rotation once a file gets bigger than a given threshold.
 */
final class SizeRotationPolicy: FileAppenderRotationPolicy {
  /// The maximum size of the file in octets before rotation is requested.
  private struct State {
    var maxFileSize: UInt64
    var currentFileSize: UInt64 = 0
  }
  private let state: Synchronized<State>
  public var maxFileSize: UInt64 {
    get { state.withValue { $0.maxFileSize } }
    set { state.withValue { $0.maxFileSize = newValue } }
  }

  /// Creates a rotation policy with a max file size in octet.
  init(maxFileSize: UInt64) {
    self.state = Synchronized(State(maxFileSize: maxFileSize))
  }
  
  func appenderDidOpenFile(atPath path: String) {
    let fileManager = FileManager.default
    do {
      let fileAttributes = try fileManager.attributesOfItem(atPath: path)
      state.withValue { $0.currentFileSize = fileAttributes[FileAttributeKey.size] as? UInt64 ?? 0 }
    } catch {
      state.withValue { $0.currentFileSize = 0 }
    }
  }
  
  func appenderDidAppend(data: Data) {
    state.withValue { $0.currentFileSize += UInt64(data.count) }
  }
  
  func shouldRotate() -> Bool {
    return state.withValue { $0.currentFileSize > $0.maxFileSize }
  }
}
