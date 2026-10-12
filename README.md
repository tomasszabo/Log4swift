# Log4Swift

## Swift 6

This fork now targets **Swift 6 language mode**, not just a Swift 6 compiler.
The package, tests, podspec and legacy Xcode configurations use mode 6.
Synchronous logging from any thread and deferred background logging remain
supported; the library is **not main-actor-only**.

Swift 6 support is available on **`master`**. Install directly from this fork
using the examples below, or pin a reviewed commit for reproducible builds.

[![License](https://img.shields.io/badge/License-Apache%20v2.0-blue.svg?style=flat
            )](http://mit-license.org)
![Platform](http://img.shields.io/badge/platform-macOS,iOS,tvOS-lightgrey.svg?style=flat)
[![Language](http://img.shields.io/badge/language-swift-orange.svg?style=flat
             )](https://developer.apple.com/swift)
[![Cocoapod](http://img.shields.io/cocoapods/v/Log4swift.svg?style=flat)](http://cocoadocs.org/docsets/Log4swift/)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Travis-ci Build Status](https://travis-ci.org/jduquennoy/Log4swift.svg)](https://travis-ci.org/jduquennoy/Log4swift)

Log4Swift is a logging library for swift projects, that will allow you to log in a very flexible way.

Its ultimate goal is to be the tool you need to make your logs as valuable as possible, both in your developpment environment and in production.

## Compatibility
Swift Package Manager requires **Swift tools/compiler 6.0+** and an Apple SDK;
it has been validated with Xcode 27 / Swift 6.4 on macOS and iOS Simulator.
The package, CocoaPods spec and legacy Xcode configurations declare
**macOS 12+, iOS 15+, tvOS 15+ and watchOS 9+**.
Linux is not supported: Objective-C interoperability, ASL and Apple's
logging/networking frameworks are required.

- For swift 3, use version 1.0.2 ([tag v1.0.2](https://github.com/jduquennoy/Log4swift/releases/tag/v1.0.2))
- For swift 2.3, use version 1.0.0b5 ([tag v1.0.0b5](https://github.com/jduquennoy/Log4swift/releases/tag/v1.0.0b5))

It can be used from Swift or Objective-C (or a mix of both) on the supported Apple platforms.

## How to use

### Swift Package Manager

Add this repository URL in Xcode's **File > Add Package Dependencies**, then
select the **Log4swift** library product and this fork's **`master`** branch:

```swift
.package(
  url: "https://github.com/tomasszabo/Log4swift.git",
  branch: "master"
)
```

For reproducible application builds, pin a reviewed revision or a subsequent
release tag and commit the application's `Package.resolved`. For a local checkout:

```swift
dependencies: [
  .package(path: "../Log4swift")
]
// In your target's dependencies:
.product(name: "Log4swift", package: "log4swift")
```

Use `import Log4swift`; synchronous logging syntax is retained, with the Swift 6
concurrency API changes described below. The package compiles the ASL wrapper and bundled NSLogger client
in separate native targets and re-exports their declarations. File,
standard-output, NSLog, ASL, unified/system and NSLogger appenders are
preserved; NSLogger is excluded on watchOS, as in the existing framework.
No remote package dependencies are needed. NSLogger's Objective-C logging
macros are not imported into Swift; Objective-C users can still include
the bundled `NSLogger.h` header explicitly.

The existing Xcode project, umbrella header and CocoaPods source layout
remain available. The package-only workspace `Log4swift-Package.xcworkspace`
avoids selecting the legacy project when running package tests in Xcode.
The existing `LICENSE`, `NOTICE`, and NSLogger's BSD `LICENSE`/`CREDITS`
remain in the repository and must accompany redistributions.
Swift language mode is declared by the package and podspec; the deprecated
`.swift-version` file has been removed to avoid conflicting CocoaPods settings.

#### Language mode and concurrency

Swift 6 strict concurrency is enabled for every Swift package target.
`Logger`, `LoggerFactory`, `PatternFormatter`, built-in rotation policies and
`FileObserver` have checked Sendable conformance. Shared configuration, caches,
formatting closures and file resources are protected by one recursive lock
domain, avoiding lock-order inversions across the logging object graph.
The factory's file-observer delegate is weak, preventing an auto-reload cycle.

The internal synchronized-state container has a narrowly scoped
`@unchecked Sendable` conformance because Swift cannot prove lock ownership.
The open `Appender` base and its subclasses also restate unchecked conformance:
Swift cannot enforce synchronization in subclass overrides or verify native
ASL/NSLogger handles. Built-in mutable state and native calls are protected;
this is a tested synchronization contract, not a blanket concurrency bypass.

**Breaking changes for custom code:**

- Deferred message closures are `@Sendable`, including Objective-C block
  entry points when called from Swift. Capture immutable Sendable values or
  explicitly synchronized state, not mutable local variables or UI objects.
- `LogInfoDictionary` values must be both `CustomStringConvertible` and
  `Sendable`. Standard strings, numbers and `LogLevel` satisfy this.
- Custom `Formatter`, `FileAppenderRotationPolicy` and `FileObserverDelegate`
  implementations must be Sendable and synchronize mutable state. Observer
  delegates are class-bound and weakly retained; retain your own delegate.
- Custom `Appender` subclasses must restate `@unchecked Sendable` and protect
  **all** mutable state, including property access, direct `performLog` calls
  and updates. Use the inherited `withSynchronization` helper or an equivalent
  audited lock. Do not wait for other threads while holding that lock.

```swift
let logger = Logger.getLogger("my.app")
let message = "Background work completed"
Task.detached {
    logger.info { message }
}
```

Accepted messages capture their destination array and asynchronous mode at
submission. A later logger reconfiguration does not redirect an already queued
message. Appender thresholds/formatters are read under synchronization at
delivery. Deferred messages preserve serial queue submission order and capture
timestamp/thread metadata on the caller, not the worker.

Configuration setters and logging can run concurrently. For multi-property
custom updates, use a synchronized block; separate property assignments are not
an atomic transaction. Synchronization serializes destination work, so slow
appenders can delay other loggers. Native ASL/NSLogger clients remain Objective-C,
not internal Swift 5 targets. Raw exported native APIs and Objective-C block
captures remain the caller's concurrency responsibility.

#### Building and testing

```sh
swift build
swift test
swift build -c release
swift test --sanitize thread --filter ConcurrencyTests
```

The package reuses the meaningful XCTest suite for logging, hierarchical
factory configuration, plist resources, formatters, appenders, file rotation
and utilities. It excludes an obsolete empty duplicate test template and
tests that query ASL/unified system-log persistence or connect to NSLogger
viewers: those rely on permissions, debug-log retention or external services.
Package-native smoke tests verify native linking, runtime discovery and
NSLogger defaults without starting network discovery. Some legacy factory
tests still configure NSLogger and can attempt local/placeholder connections;
no running viewer is required for macOS tests.

For an iOS Simulator, use the shared package scheme and representative suite
(replace `SIMULATOR_UDID` with an available simulator ID):

```sh
xcodebuild -workspace Log4swift-Package.xcworkspace -scheme Log4swift-Package \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UDID' \
  -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO \
  -only-testing:Log4swiftTests/LoggerTests \
  -only-testing:Log4swiftTests/LoggerFactoryTests \
  -skip-testing:Log4swiftTests/LoggerFactoryTests/testConfigureForNSLoggerReplacesCurrentConfiguration \
  -only-testing:Log4swiftTests/PatternFormatterTests \
  -only-testing:Log4swiftTests/FileAppenderTests \
  -only-testing:Log4swiftTests/SystemAppenderTests \
  -only-testing:Log4swiftTests/SubclassingTests \
  -only-testing:Log4swiftTests/NativeAppenderPackageTests \
  -only-testing:Log4swiftTests/ConcurrencyTests \
  -parallel-testing-enabled NO test
```

The simulator selection omits legacy stdout descriptor-redirection tests
(which interfere with the simulator test runner), wall-clock polling
asynchrony tests (which are sensitive to background scheduling), and
network-starting factory configuration tests. The full portable suite runs
on macOS. Package test files live under `.build/test-files` on macOS or the
test sandbox's Application Support directory on iOS, not the system temporary
directory. CI runs the macOS suite, release build, representative iOS tests
and an unsigned legacy iOS framework build. No signing credentials, physical
devices or NSLogger viewers are needed.
Swift 6 validation with Xcode 27 / Swift 6.4 passes **265 macOS tests**,
**164 selected iOS simulator tests**, and **11 concurrency/subclassing tests
under Thread Sanitizer**, with no sanitizer race reports. macOS/iOS/tvOS/watchOS
Release package builds, the unsigned legacy iOS framework build and iOS
CocoaPods lint pass. Compiler commands confirm actual `-swift-version 6`;
no logger concurrency warnings remain. Existing native ASL/NSLogger deprecation
warnings remain. Older deployment targets and external log viewers were not
runtime-tested.

### Manually
Clone the repo on your machine, and compile the target that feets your need (OS X, iOS, ...). It will produce a library that you can use in your project.
As long as the swift ABI is not stable, you will need to recompile the library if you change the version of the compiler used for your project. Because of that, you should rather consider one of the other methods (see bellow).

### CocoaPod
For this fork:

```ruby
pod 'Log4swift', :git => 'https://github.com/tomasszabo/Log4swift.git',
                :branch => 'master'
```

Add those lines to your Podfile to embed this library in an iOS project (with the versions you want for the lib and the target):

```
platform :ios, '15.0'
pod 'Log4swift', :git => 'https://github.com/tomasszabo/Log4swift.git',
                :branch => 'master'
use_frameworks!
```
And in an OS X project :

```
platform :osx, '12.0'
pod 'Log4swift', :git => 'https://github.com/tomasszabo/Log4swift.git',
                :branch => 'master'
use_frameworks!
```

### Carthage
Add this line to your Cartfile (with the version you want):

```
github "tomasszabo/Log4swift" "master"
```

## Features
Here are the main features you can expect from Log4swift :

* straightforward to use for simple cases : default configuration should just work, one-line configuration for typical uses like logging to IDE console or to system logs
* flexible for more complexe cases, with multi-destination logging, hierarchic loggers configuration, ...
* multiple destinations available, including network logging, using NSLogger
  * file logging
  * network logging using NSLogger
  * Xcode console logging, including colorized logs (with the XcodeColors plugin installed)
* dynamically configurable by code
* configurable by file, with auto-reload on update possibility (opt-in feature)
* asynchronous logging, performed on a secondary thread (opt-in feature). Async behavior can be activated per logger.


Another goal, that I think we all share, is to have readable and tested code.

* The code coverage of Log4swift's code (excluding third party code) is 100% for most of the source files, and very close to it for others.
* Feel free to send feedbacks or contribute if you find the code not readable enough, or if you have ideas to highen the quality of that code !

## Concepts
The three main concepts of this library are borrowed from log4j :

### Loggers
Loggers are the objects to which logs are send at the first place.
They are identified by a UTI identifier (like "project.module.function") that are hierachical. When a log message is sent, the logger with the longest matching UTI will be responsible for dealing the log.
A root logger will deal with logs that matches no specific logger.

A logger defines a threshold level. Logs bellow this level will be ignored. Non ignored levels are sent to the appenders associated to the logger.

### Appenders
Appenders are attached to loggers. They are responsible for writing the logs to their destination. They are identified by an identifier, that is used when loading configuration to attache appenders to their loggers. One appender might be attached to multiple loggers.

Appenders also have a threshold to filter out messages.

### Formatters
Formatters are attached to appenders. Their job is to modify the message to apply it a specific formatting before it is sent to its final destination. One formatter might be attached to multiple appenders.

## Some more details on features
### Mutliple appenders per logger
One logger can have multiple appenders. You can for exemple define a logger that will log everything to the console, but that will also log error messages to a file for latter use.

```
let logger = Logger.getLogger("test.logger");
let stdOutAppender = StdOutAppender("console");
let fileAppender = FileAppender(identifier: "errorFile", filePath: "/var/log/error.log");

stdOutAppender.thresholdLevel = .Debug;
fileAppender.thresholdLevel = .Error;
logger.appenders = [stdOutAppender, fileAppender];

logger.debug ("This message will go to the console");
logger.error ("This message will go to the console and the error log file");  }
```

(this code compiles on Xcode 7.3, using swift 2.2)

### Formatters associated to appenders
Formatters allows you to apply a specific formatting to your log message, either adding information to the logged message or modifying the message to have it complying to some constraintes.

Formatters are associated to appenders. This way, you can log human readable logs to Xcode's console, while logging with more info regexp friendly format in a file.

### Log with closures
Providing a closure instead of a string is pretty handy if the code that generates the message is heavy : the closure will only be executed if the logs are to be issued. No need to encapsulate the code in an if structure.

```
Logger.debug { someHeavyCodeThatGeneratesTheLogMessage() }
```

Note that creating the bloc is not completely free (some magic happen behind the scene, like variable capture). But for most uses, the cost should be negligible.

### Log asynchronously
Loggers can be configured individualy to log asynchronously. Asynchronous logging will return almost immediately when a log is requested, while the real log will be issued in background on a low priority thread.

Order of messages logged to asynchronous loggers is guaranteed.

Note that if asychronous loggers will execute logged closures later in time, and on an external thread.

### Flexible configuration
Loggers can be configured from a file, or using the library's API.

Using the API, you can use a dictionary, that can be stored and loaded from anywhere you want (a web service, a database, a preference file, ...).

Using a configuration file, you can request the configuration to be auto-reloaded each time the file is modified:

```
LoggerFactory.sharedInstance.readConfiguration(fromPlistFile: "/some/file.plist", autoReload: true)
```

Configuration can be modified at run time.

## Provided appenders

### The stdout appender
This appender will write log messages to stdout or stderr. It has two thresholds : the regular threshold, available on all appenders, and an error threshold.

* If the log level is bellow the general threshold, the message is ignored
* If the log level is above the general threshold but bellow the error threshold, the message is issued on stdout
* If the log level is above both the general and the error threshold, the message is issued on stderr

By default, the stdout appender is configured to send Error and Fatal messages to stderr, and all other levers to stdout.

This appender is a good choice for CLI tools.

### The file appender
This appender will write log messages to a file, specified by its path. It will create the file if needed (and possible), and will re-create it if it disapears. This allows log rotation scripts to avoid having to restart the process to ensure logs are recorded in a new file after rotation.

### The NSLogger appender
This appender uses NSLogger (https://github.com/fpillet/NSLogger) to send log messages over the network.
Not all capabilities of NSLogger are accessibles yet : only text messages can be logged.

### The ASL appender
The ASL appender sends log messages to the system logging service, provided by Apple. Your messages will we visible in the Console.app application if the ASL configuration has not been customized.

This appender is a good choice for release versions of softwares targetting exclusively systems that does not have the Unified Logging System.

**Note:** ASL has been deprecated by Apple starting with MacOS 10.12. The unified logger appender should be used instead of ASL for those platforms.

### The Unified Logging System appender
The unified logging system is the replacement of ASL starting with MacOS 10.12. This logger will log messages to this facility. Your messages will be visible in the Console.app application.

This appender is a good choice for release versions of software targetting 10.12 and latter.

### The system appender
This meta-appender will use the most appropriate system appender for the current system.

* for MacOS < 10.12, it will use the ASLAppender
* for MacOS >= 10.12, it will use the Unified Logging System appender.

This appender is the best choice for release versions of software targetting multiple versions of the system (most common case).


## Provided formatters

### The PatternFormatter

The PatternFormatter uses a simple textual pattern with marker identified by a '%' prefix to render the log messages.

As an exemple, this pattern :  
```
[%d][%l][%n] %m
```  
will produce this kind of log:  
```
[2015-02-02 12:45:23 +0000][Debug][logger.name] The message that was sent to the logger
```

See [this page](https://github.com/jduquennoy/Log4swift/wiki/Provided-Formatters) for more details, including a full list of available markers.
