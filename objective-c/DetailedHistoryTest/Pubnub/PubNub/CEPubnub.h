    // Copyright 2011 Cooliris, Inc.
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

#import <Foundation/Foundation.h>
#import "CEPubnubDelegate.h"

// All operations happen on the main thread
// Messages must be JSON compatible
@interface CEPubnub : NSObject {
@private
    __unsafe_unretained id<CEPubnubDelegate> _delegate;
    NSString *_publishKey;
    NSString *_subscribeKey;
    NSString *_secretKey;
    NSString *_host;
    NSString *_cipherKey;
    NSString *_uuids;
    
    NSMutableSet* _connections;
    NSMutableSet * _subscriptions;
    
    int _tryCount;
}

@property (nonatomic, assign) id<CEPubnubDelegate> delegate;

- (CEPubnub *)initWithSubscribeKey:(NSString *)subscribeKey useSSL:(BOOL)useSSL;

- (CEPubnub *)initWithPublishKey:(NSString *)publishKey
                    subscribeKey:(NSString *)subscribeKey
                       secretKey:(NSString *)secretKey
                          useSSL:(BOOL)useSSL;

- (CEPubnub *)initWithPublishKey:(NSString *)publishKey  // May be nil if -publishMessage:toChannel: is never used
                    subscribeKey:(NSString *)subscribeKey
                       secretKey:(NSString *)secretKey  // May be nil if -publishMessage:toChannel: is never used
                          useSSL:(BOOL)useSSL
                       cipherKey:(NSString *)cipherKey
                            uuid:(NSString *)uuid
                          origin:(NSString *)origin;

- (CEPubnub *)initWithPublishKey:(NSString *)publishKey
                    subscribeKey:(NSString *)subscribeKey
                       secretKey:(NSString *)secretKey
                       cipherKey:(NSString *)cipherKey
                          useSSL:(BOOL)useSSL;

- (CEPubnub *)initWithPublishKey:(NSString *)publishKey
                    subscribeKey:(NSString *)subscribeKey
                       secretKey:(NSString *)secretKey
                       cipherKey:(NSString *)cipherKey
                            uuid:(NSString *)uuid
                          useSSL:(BOOL)useSSL;

+ (NSString *)getUUID;

- (void)publish:(NSDictionary *)arg1;
- (void)publish:(NSString *)message onChannel:(NSString *)channel;
- (void)fetchHistory:(NSDictionary *)arg1;
- (void)detailedHistory:(NSDictionary *)arg1;
- (void)unsubscribeFromAllChannels;
- (void)getTime;
- (void)subscribe:(NSString *)channel;  // Does nothing if already subscribed
- (void)unsubscribeFromChannel:(NSString *)channel;  // Does nothing if not subscribed
- (BOOL)isSubscribedToChannel:(NSString *)channel;
- (void)hereNow:(NSString *)channel;
- (void)presence:(NSString *)channel;

- (void)here_now:(NSString *)channel __deprecated;
+ (BOOL)isApplicationActive;
+ (void)setApplicationActive:(BOOL) state;
@end

@interface ChannelStatus :NSObject

@property(nonatomic, retain) NSString *channel;
@property(nonatomic, nonatomic) BOOL connected;
@property(nonatomic, nonatomic) BOOL first;

@end


