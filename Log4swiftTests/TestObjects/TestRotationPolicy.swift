//
//  TestRotationPolicy.swift
//  Log4swift
//
//  Created by Jérôme Duquennoy on 20/08/2018.
//  Copyright © 2018 jerome. All rights reserved.
//

import Foundation
@testable import Log4swift

final class TestRotationPolicy: FileAppenderRotationPolicy {
  private struct State {
    var shouldRotate = false
    var appendedData: Data?
    var openedFilePath: String?
  }
  private let state = Synchronized(State())
  public var shouldRotateValue: Bool {
    get { state.withValue { $0.shouldRotate } }
    set { state.withValue { $0.shouldRotate = newValue } }
  }
  public var appendedData: Data? {
    get { state.withValue { $0.appendedData } }
    set { state.withValue { $0.appendedData = newValue } }
  }
  public var openedFilePath: String? {
    get { state.withValue { $0.openedFilePath } }
    set { state.withValue { $0.openedFilePath = newValue } }
  }
  
  func appenderDidOpenFile(atPath path: String) {
    self.openedFilePath = path
  }
  
  func appenderDidAppend(data: Data) {
    self.appendedData = data
  }
  
  func shouldRotate() -> Bool {
    return self.shouldRotateValue
  }
}
