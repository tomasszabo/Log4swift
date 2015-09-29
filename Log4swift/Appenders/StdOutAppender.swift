//
//  StdOutAppender.swift
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

/**
StdOutAppender will print the log to stdout or stderr depending on thresholds and levels.
* If general threshold is reached but error threshold is undefined or not reached, log will be printed to stdout
* If both general and error threshold are reached, log will be printed to stderr
*/
public class StdOutAppender: Appender {
  public enum DictionaryKey: String {
    case ErrorThreshold = "ErrorThresholdLevel"
  };
  
  internal enum TTYType {
    case Xcode
    case XtermColor
  }
  
  public var errorThresholdLevel: LogLevel? = .Error;
  private var textColors = [LogLevel: TTYColor]();
  private var backgroundColors = [LogLevel: TTYColor]();
  internal let ttyType: TTYType;
  
  public required init(_ identifier: String) {
    let xcodeColors = NSProcessInfo().environment["XcodeColors"];
    let terminalType = NSProcessInfo().environment["TERM"];
    switch (xcodeColors, terminalType) {
    case (.Some("YES"), _):
      self.ttyType = .Xcode;
    default:
      self.ttyType = .XtermColor;
    }
    
    super.init(identifier);
  }
  
  public override func updateWithDictionary(dictionary: Dictionary<String, AnyObject>, availableFormatters: Array<Formatter>) throws {
    
    try super.updateWithDictionary(dictionary, availableFormatters: availableFormatters);
    
    if let errorThresholdString = (dictionary[DictionaryKey.ErrorThreshold.rawValue] as? String) {
      if let errorThreshold = LogLevel(errorThresholdString) {
        errorThresholdLevel = errorThreshold;
      } else {
        throw InvalidOrMissingParameterException("Invalide '\(DictionaryKey.ErrorThreshold.rawValue)' value for console appender '\(self.identifier)'");
      }
    } else {
      errorThresholdLevel = nil;
    }
  }
  
  override func performLog(log: String, level: LogLevel, info: LogInfoDictionary) {
    var destinationFile = stdout;
    
    if let errorThresholdLevel = self.errorThresholdLevel {
      if(level.rawValue >= errorThresholdLevel.rawValue) {
        destinationFile  = stderr;
      }
    }
    
    let finalLogString = self.colorizeLog(log, level: level) + "\n";
    fputs(finalLogString, destinationFile);
  }
  
}

// MARK: - Color management extension
extension StdOutAppender {
  public enum TTYColor {
    case Black
    case DarkGrey
    case Grey
    case LightGrey
    case White
    case LightRed
    case Red
    case DarkRed
    case LightGreen
    case Green
    case DarkGreen
    case LightBlue
    case Blue
    case DarkBlue
    case LightYellow
    case Yellow
    case DarkYellow
    case Purple
    case lightPurple
    case DarkPurple
    
    private func xtermCode() -> Int {
      switch(self) {
      case Black : return 0;
      case DarkGrey : return 238;
      case Grey : return 241;
      case LightGrey : return 251;
      case White : return 15;
      case LightRed : return 199;
      case Red : return 9;
      case DarkRed : return 1;
      case LightGreen : return 46;
      case Green : return 2;
      case DarkGreen : return 22;
      case LightBlue : return 45;
      case Blue : return 21;
      case DarkBlue : return 18;
      case LightYellow : return 228;
      case Yellow : return 11;
      case DarkYellow : return 3;
      case Purple : return 93;
      case lightPurple : return 135;
      case DarkPurple : return 55;
      }
    }
    
    private func xcodeCode() -> String {
      switch(self) {
      case Black : return "0,0,0";
      case DarkGrey : return "68,68,68";
      case Grey : return "98,98,98";
      case LightGrey : return "200,200,200";
      case White : return "255,255,255";
      case LightRed : return "255,37,174";
      case Red : return "255,0,0";
      case DarkRed : return "201,14,19";
      case LightGreen : return "57,255,42";
      case Green : return "0,255,0";
      case DarkGreen : return "18,94,11";
      case LightBlue : return "47,216,255";
      case Blue : return "0,0,255";
      case DarkBlue : return "0,18,133";
      case LightYellow : return "255,255,143";
      case Yellow : return "255,255,56";
      case DarkYellow : return "206,203,43";
      case Purple : return "131,46,252";
      case lightPurple : return "172,105,252";
      case DarkPurple : return "92,28,173";
      }
    }
    
    private func codeForTTYType(type: TTYType) -> String {
      switch(type) {
      case .XtermColor: return String(self.xtermCode());
      case .Xcode: return self.xcodeCode();
      }
    }
  };
  
  private var textColorPrefix: String {
    switch(self.ttyType) {
    case .Xcode: return "\u{1B}[fg";
    case .XtermColor: return "\u{1B}[38;5;";
    }
  }
  
  private var backgroundColorPrefix: String {
    switch(self.ttyType) {
    case .Xcode: return "\u{1B}[bg";
    case .XtermColor: return "\u{1B}[48;5;";
    }
  }
  
  private var colorSuffix: String {
    switch(self.ttyType) {
    case .Xcode: return ";";
    case .XtermColor: return "m";
    }
  }
  
  private var resetColorSequence: String {
    switch(self.ttyType) {
    case .Xcode: return "\u{1B}[;";
    case .XtermColor: return "\u{1B}[0m";
    }
  }
  
  private func colorizeLog(log: String, level: LogLevel) ->  String {
    var shouldResetColors = false;
    var colorizedLog = "";
    
    if let textColor = self.textColors[level] {
      shouldResetColors = true;
      colorizedLog += self.textColorPrefix + textColor.codeForTTYType(self.ttyType) + self.colorSuffix;
    }
    if let backgroundColor = self.backgroundColors[level] {
      shouldResetColors = true;
      colorizedLog += self.backgroundColorPrefix + backgroundColor.codeForTTYType(self.ttyType) + self.colorSuffix;
    }

    colorizedLog += log;
    
    if(shouldResetColors) {
      colorizedLog += self.resetColorSequence;
    }
    
    return colorizedLog;
  }
  
  /// :param: color The color to set, or nil to set no color
  /// :param: level The log level to which the provided color applies
  public func setTextColor(color: TTYColor?, level: LogLevel) {
    if let color = color {
      self.textColors[level] = color;
    } else {
      self.textColors.removeValueForKey(level);
    }
  }

  /// :param: color The color to set, or nil to set no color
  /// :param: level The log level to which the provided color applies
  public func setBackgroundColor(color: TTYColor?, level: LogLevel) {
    if let color = color {
      self.backgroundColors[level] = color;
    } else {
      self.backgroundColors.removeValueForKey(level);
    }
  }

}