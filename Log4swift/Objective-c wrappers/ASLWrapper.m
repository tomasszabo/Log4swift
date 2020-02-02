//
//  ASLWrapper.m
//  Log4swift
//
//  Created by Jérôme Duquennoy on 29/07/15.
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

#import "ASLWrapper.h"
#import <asl.h>

@implementation ASLWrapper {
  aslclient logClient;
  dispatch_queue_t loggingQueue;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    logClient = asl_open(NULL, NULL, 0);
    char filter = (char) ASL_FILTER_MASK_UPTO(ASL_LEVEL_DEBUG);
    asl_set_filter(logClient, filter); // We don't want ASL to filter messages
    loggingQueue = dispatch_queue_create("Log4swift.ASLLoggingQueue", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (void)dealloc {
  if(logClient != NULL) {
    asl_close(logClient);
    logClient = NULL;
    
    loggingQueue = NULL;
  }
}

- (void)logMessage:(NSString *)log level:(int)level category:(NSString *)category {
  static char const *const levelStrings[] = {"0", "1", "2", "3", "4", "5", "6", "7"};
  dispatch_sync(loggingQueue, ^{
    if(self->logClient != NULL) {
      int aslLogLevel = [self _logLevelToAslLevel:level];
      aslmsg aslMessage = asl_new(ASL_TYPE_MSG);
      asl_set(aslMessage, ASL_KEY_FACILITY, [category UTF8String]);
      asl_set(aslMessage, ASL_KEY_LEVEL, levelStrings[aslLogLevel]);
      asl_set(aslMessage, ASL_KEY_MSG, [log UTF8String]);
      asl_send(self->logClient, aslMessage);
      asl_free(aslMessage);
    }
    
  });
}

- (int)getLevelOfMessageMatchingText:(NSString *)message {
  aslmsg query = asl_new(ASL_TYPE_QUERY);
  asl_set_query(query, ASL_KEY_MSG, [message UTF8String], ASL_QUERY_OP_EQUAL);
  aslresponse response = asl_search(logClient, query);
  asl_free(query);
  
  int foundLevel = -1;
  aslmsg foundMessage = asl_next(response);
  if (foundMessage != NULL) {
    const char *level = asl_get(foundMessage, ASL_KEY_LEVEL);
    if (level != NULL) {
      foundLevel = [[NSString stringWithCString:level encoding:NSUTF8StringEncoding] intValue];
    }
  }

  asl_release(response);
  
  return [self _aslLevelToLogLevel:foundLevel];
}

- (NSString *)getFacilityOfMessageMatchingText:(NSString *)message {
  aslmsg query = asl_new(ASL_TYPE_QUERY);
  asl_set_query(query, ASL_KEY_MSG, [message UTF8String], ASL_QUERY_OP_EQUAL);
  aslresponse response = asl_search(logClient, query);
  asl_free(query);
  
  NSString *foundFacility = nil;
  aslmsg foundMessage = asl_next(response);
  if (foundMessage != NULL) {
    const char *level = asl_get(foundMessage, ASL_KEY_FACILITY);
    if (level != NULL) {
      foundFacility = [NSString stringWithCString:level encoding:NSUTF8StringEncoding];
    }
  }
  
  asl_release(response);
  
  return foundFacility;
}

- (int)_logLevelToAslLevel:(int)logLevel {
  int aslLogLevel = ASL_LEVEL_DEBUG;
  switch(logLevel) {
    case 0:
    case 1:
      aslLogLevel = ASL_LEVEL_DEBUG;
      break;
    case 2:
      aslLogLevel = ASL_LEVEL_INFO;
      break;
    case 3:
      aslLogLevel = ASL_LEVEL_WARNING;
      break;
    case 4:
      aslLogLevel = ASL_LEVEL_ERR;
      break;
    case 5:
      aslLogLevel = ASL_LEVEL_CRIT;
      break;
    case 6:
      // If the LogLevel is OFF this piece of code should have never been reached in the first place
      // Mapping it to ASL_LEVEL_CRIT if does nevertheless.
      aslLogLevel = ASL_LEVEL_CRIT;
      break;
  }
  return aslLogLevel;
}

- (int)_aslLevelToLogLevel:(int)aslLevel {
  int aslLogLevel = ASL_LEVEL_DEBUG;
  switch(aslLevel) {
    case ASL_LEVEL_DEBUG:
      aslLogLevel = 1;
      break;
    case ASL_LEVEL_INFO:
    case ASL_LEVEL_NOTICE:
      aslLogLevel = 2;
      break;
    case ASL_LEVEL_WARNING:
      aslLogLevel = 3;
      break;
    case ASL_LEVEL_ERR:
      aslLogLevel = 4;
      break;
    case ASL_LEVEL_CRIT:
    case ASL_LEVEL_ALERT:
    case ASL_LEVEL_EMERG:
      aslLogLevel = 5;
      break;
  }
  return aslLogLevel;
}
@end
