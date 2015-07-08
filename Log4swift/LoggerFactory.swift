//
//  LoggerFactory.swift
//  log4swift
//
//  Created by Jérôme Duquennoy on 14/06/2015.
//  Copyright © 2015 Jérôme Duquennoy. All rights reserved.
//
// Log4swift is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Log4swift is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Foobar. If not, see <http://www.gnu.org/licenses/>.
//

/**
The logger factory is responsible for
* loading configuration from files or dictionaries
* holding the loggers and appenders
* matching UTI identifiers to loggers
*/
@objc public class LoggerFactory {
  static public let sharedInstance = LoggerFactory();
  
  /// Errors that can be thrown by logger factory
  public enum Error: ErrorType {
    case InvalidLoggerIdentifier
  }
  
  /// The root logger is the catchall logger used when no other logger matches. It is the only non-optional logger of the factory.
  public let rootLogger = Logger();
  internal var loggers = Dictionary<String, Logger>();
  
  // MARK: Configuration

  /// Adds the given logger to the list of available loggers. If a logger with the same identifier already exists, it will be replaced by the new one.
  /// Adding a logger with an empty identifier will cause an error. Use the root logger instead of defining a logger with an empty identifier.
  @objc public func registerLogger(newLogger: Logger) throws {
    if(newLogger.identifier.isEmpty) {
      throw Error.InvalidLoggerIdentifier;
    }
    
    self.loggers[newLogger.identifier] = newLogger;
  }
  
  @objc public func resetConfiguration() {
    self.loggers.removeAll();
    self.rootLogger.resetConfiguration();
  }
  
  // MARK: Acccessing loggers

  /// Returns the logger for the given identifier.
  /// If an exact match is found, the associated logger will be returned. If not, a new logger will be created on the fly base on the logger with with the longest maching identifier.
  /// Ultimately, if no logger is found, the root logger will be used as a base.
  /// Once the logger has been created, it is associated with its identifier, and can be updated independently from other loggers.
  @objc public func getLogger(identifierToFind: String) -> Logger {
    let foundLogger: Logger;
    
    if let loggerFromCache = self.loggers[identifierToFind] {
      foundLogger = loggerFromCache;
    } else {
      var reducedIdentifier = identifierToFind.stringByRemovingLastComponentWithDelimiter(".");
      var loggerToCopy = self.rootLogger;
      while (loggerToCopy === self.rootLogger && !reducedIdentifier.isEmpty) {
        if let loggerFromCache = self.loggers[reducedIdentifier] {
          loggerToCopy = loggerFromCache;
        }
        reducedIdentifier = reducedIdentifier.stringByRemovingLastComponentWithDelimiter(".");
      }
      
      foundLogger = Logger(loggerToCopy: loggerToCopy, newIdentifier: identifierToFind);
      self.loggers[identifierToFind] = foundLogger;
    }
    
    return foundLogger;
  }
  
}