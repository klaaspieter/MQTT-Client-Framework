//
//  MQTTClientSubscriptionTests.m
//  MQTTClient
//
//  Created by Christoph Krey on 14.01.14.
//  Copyright (c) 2014 Christoph Krey. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MQTTClient.h"
#import "MQTTClientTests.h"

@interface MQTTClientSubscriptionTests : XCTestCase <MQTTSessionDelegate>
@property (strong, nonatomic) MQTTSession *session;
@property (nonatomic) MQTTSessionEvent event;
@property (nonatomic) UInt16 mid;
@property (nonatomic) UInt16 sentMid;
@property (nonatomic) NSArray *qoss;
@property (nonatomic) BOOL timeout;
@property (nonatomic) int type;
@property (strong, nonatomic) NSDictionary *parameters;

@end

@implementation MQTTClientSubscriptionTests

- (void)setUp
{
    [super setUp];
    self.parameters = PARAMETERS;
    
    self.session = [[MQTTSession alloc] initWithClientId:nil
                                                userName:nil
                                                password:nil
                                               keepAlive:60
                                            cleanSession:YES
                                                    will:NO
                                               willTopic:nil
                                                 willMsg:nil
                                                 willQoS:0
                                          willRetainFlag:NO
                                           protocolLevel:[self.parameters[@"protocollevel"] intValue]
                                                 runLoop:[NSRunLoop currentRunLoop]
                                                 forMode:NSRunLoopCommonModes];
    self.session.delegate = self;
    self.event = -1;
    
    self.timeout = FALSE;
    [self performSelector:@selector(ackTimeout:)
               withObject:self.parameters[@"timeout"]
               afterDelay:[self.parameters[@"timeout"] intValue]];
     
    
    [self.session connectToHost:self.parameters[@"host"]
                           port:[self.parameters[@"port"] intValue]
                       usingSSL:[self.parameters[@"tls"] boolValue]];
    
    while (self.event == -1 && !self.timeout) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
    XCTAssert(!self.timeout, @"timeout");
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
        
    self.timeout = FALSE;
    self.mid = 0;
    self.qoss = @[];
    self.event = -1;
}

- (void)tearDown
{
    self.event = -1;
    
    self.timeout = FALSE;
    [self performSelector:@selector(ackTimeout:)
               withObject:self.parameters[@"timeout"]
               afterDelay:[self.parameters[@"timeout"] intValue]];
    
    [self.session close];
    
    while (self.event == -1 && !self.timeout) {
        NSLog(@"waiting for disconnect");
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
    XCTAssert(!self.timeout, @"timeout");
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    self.session.delegate = nil;
    self.session = nil;
    
    [super tearDown];
}

/*
 * Subscriptions
 */

- (void)testSubscribe_with_wrong_flags_MQTT_3_8_1_1
{
    NSLog(@"can't test [MQTT-3.8.1-1]");
}

- (void)testUnsubscribe_with_wrong_flags_MQTT_3_10_1_1
{
    NSLog(@"can't test [MQTT-3.10.1-1]");
}

- (void)testSubscribeWMultipleTopics_None
{
    [self testMultiSubscribeCloseExpected:@{}];
}

- (void)testSubscribeWMultipleTopics_One
{
    [self testMultiSubscribeSubackExpected:@{@"MQTTClient": @(2)}];
}

- (void)testSubscribeWMultipleTopics_more
{
    [self testMultiSubscribeSubackExpected:@{@"MQTTClient": @(0), @"MQTTClient/abc": @(0), @"MQTTClient/#": @(1)}];
}

- (void)testSubscribeWMultipleTopics_a_lot
{
#define TOPICS 256
    NSMutableDictionary *topics = [[NSMutableDictionary alloc] initWithCapacity:TOPICS];
    for (int i = 0; i < TOPICS; i++) {
        [topics setObject:@(1) forKey:[NSString stringWithFormat:@"MQTTClient/a/lot/%d", i]];
    }
    
    [self testMultiSubscribeSubackExpected:topics];
}

- (void)testSubscribeQoS0
{
    [self testSubscribeSubackExpected:@"MQTTClient/#" atLevel:0];
}

- (void)testSubscribeQoS1
{
    [self testSubscribeSubackExpected:@"MQTTClient/#" atLevel:1];
}

- (void)testSubscribeQoS2
{
    [self testSubscribeSubackExpected:@"MQTTClient/#" atLevel:2];
}

- (void)testSubscribeTopicPlain
{
    [self testSubscribeSubackExpected:@"MQTTClient" atLevel:0];
}

- (void)testSubscribeTopicHash {
    [self testSubscribeSubackExpected:@"#" atLevel:0];
}

- (void)testSubscribeTopicHashnotalone
{
    [self testSubscribeCloseExpected:@"#MQTTClient" atLevel:0];
}

- (void)testSubscribeTopicEmpty
{
    [self testSubscribeCloseExpected:@"" atLevel:0];
}

- (void)testSubscribeTopicHashnotlast
{
    [self testSubscribeCloseExpected:@"MQTTClient/#/def" atLevel:0];
}

- (void)testSubscribeTopicPlus
{
    [self testSubscribeSubackExpected:@"+" atLevel:0];
}

- (void)testSubscribeTopicSlash
{
    [self testSubscribeSubackExpected:@"/" atLevel:0];
}

- (void)testSubscribeTopicPlusnotalone_MQTT_4_7_1_3
{
    [self testSubscribeCloseExpected:@"MQTTClient+" atLevel:0];
}

- (void)testSubscribeTopicEmpty_MQTT_4_7_3_1
{
    [self testSubscribeCloseExpected:@"" atLevel:0];
}

- (void)testSubscribeTopicNone
{
    [self testSubscribeCloseExpected:nil atLevel:0];
}

- (void)testSubscribeTopic_0x00_in_topic
{
    NSLog(@"can't test [MQTT-4.7.3-2]");
}


- (void)testSubscribeLong_MQTT_4_7_3_3
{
    NSString *topic = @"aa";
    for (UInt32 i = 2; i <= 32768; i *= 2) {
        topic = [topic stringByAppendingString:topic];
    }
    NSLog(@"LongSubscribe (%lu)", strlen([[topic substringFromIndex:1] UTF8String]));
    [self testSubscribeSubackExpected:[topic substringFromIndex:1] atLevel:0];
}


- (void)testSubscribeSameTopicDifferentQoSa_MQTT_3_8_4_3
{
    [self testSubscribeSubackExpected:@"mqttitude/#" atLevel:0];
}
- (void)testSubscribeSameTopicDifferentQoSb_MQTT_3_8_4_3
{
    [self testSubscribeSubackExpected:@"mqttitude/#" atLevel:1];
}
- (void)testSubscribeSameTopicDifferentQoSc_MQTT_3_8_4_3
{
    [self testSubscribeSubackExpected:@"mqttitude/#" atLevel:2];
}
- (void)testSubscribeSameTopicDifferentQoSd_MQTT_3_8_4_3
{
    [self testSubscribeSubackExpected:@"mqttitude/#" atLevel:1];
}
- (void)testSubscribeSameTopicDifferentQoSe_MQTT_3_8_4_3
{
    [self testSubscribeSubackExpected:@"mqttitude/#" atLevel:0];
}


/*
 * Unsubscribe tests
 */
- (void)testUnsubscribeTopicPlain
{
    [self testUnsubscribeTopic:@"abc"];
}

- (void)testUnubscribeTopicHash {
    [self testUnsubscribeTopic:@"#"];
}

- (void)testUnsubscribeTopicHashnotalone
{
    [self testUnsubscribeTopic:@"#abc"];
}

- (void)testUnsubscribeTopicPlus
{
    [self testUnsubscribeTopic:@"+"];
}

- (void)testUnsubscribeTopicEmpty
{
    [self testUnsubscribeTopicCloseExpected:@""];
}

- (void)testUnsubscribeTopicNone
{
    [self testUnsubscribeTopic:nil];
}

- (void)testUnsubscribeTopicZero
{
    [self testUnsubscribeTopic:@"a\0b"];
}

- (void)testMultiUnsubscribe_None
{
    [self testMultiUnsubscribeTopic:@[]];
}

- (void)testMultiUnsubscribe_One
{
    [self testMultiUnsubscribeTopic:@[@"abc"]];
}

- (void)testMultiUnsubscribe_more
{
    [self testMultiUnsubscribeTopic:@[@"abc", @"ab/+/ef", @"+", @"#", @"abc/df", @"a/b/c/#"]];
}

/*
 * helpers
 */

- (void)testSubscribeSubackExpected:(NSString *)topic atLevel:(UInt8)qos
{
    [self testSubscribe:topic atLevel:qos];
    XCTAssertFalse(self.timeout, @"No SUBACK received within %d seconds [MQTT-3.8.4-1]", 10);
    XCTAssert(self.event == -1, @"Event %ld happened", (long)self.event);
    XCTAssertEqual(self.mid, self.sentMid, @"msgID(%d) in SUBACK does not match msgID(%d) in SUBSCRIBE [MQTT-3.8.4-2]", self.mid, self.sentMid);
    for (NSNumber *qos in self.qoss) {
        XCTAssertNotEqual([qos intValue], 0x80, @"Returncode in SUBACK is 0x80");
        XCTAssert([qos intValue] == 0x00 || [qos intValue] == 0x01 || [qos intValue] == 0x02, @"Returncode in SUBACK invavalid [MQTT-3.9.3-2]");
    }
}

- (void)testMultiSubscribeSubackExpected:(NSDictionary *)topics
{
    [self testMultiSubscribe:topics];
    XCTAssertFalse(self.timeout, @"No SUBACK received within %d seconds [MQTT-3.8.4-1]", 10);
    XCTAssert(self.event == -1, @"Event %ld happened", (long)self.event);
    XCTAssertEqual(self.mid, self.sentMid, @"msgID(%d) in SUBACK does not match msgID(%d) in SUBSCRIBE [MQTT-3.8.4-2]", self.mid, self.sentMid);
    for (NSNumber *qos in self.qoss) {
        XCTAssertNotEqual([qos intValue], 0x80, @"Returncode in SUBACK is 0x80");
        XCTAssert([qos intValue] == 0x00 || [qos intValue] == 0x01 || [qos intValue] == 0x02, @"Returncode in SUBACK invavalid [MQTT-3.9.3-2]");
    }
}

- (void)testSubscribeCloseExpected:(NSString *)topic atLevel:(UInt8)qos
{
    [self testSubscribe:topic atLevel:qos];
    XCTAssertFalse(self.timeout, @"No close within %d seconds", 10);
    XCTAssert(self.event == MQTTSessionEventConnectionClosed, @"Event %ld happened", (long)self.event);
}

- (void)testMultiSubscribeCloseExpected:(NSDictionary *)topics
{
    [self testMultiSubscribe:topics];
    XCTAssertFalse(self.timeout, @"No close within %d seconds", 10);
    XCTAssert(self.mid == 0, @"SUBACK received");
    XCTAssert(self.event == MQTTSessionEventConnectionClosed, @"Event %ld happened", (long)self.event);
}

- (void)testSubscribeFailureExpected:(NSString *)topic atLevel:(UInt8)qos
{
    [self testSubscribe:topic atLevel:qos];
    XCTAssertFalse(self.timeout, @"No SUBACK received within %d seconds [MQTT-3.8.4-1]", 10);
    XCTAssert(self.event == -1, @"Event %ld happened", (long)self.event);
    XCTAssertEqual(self.mid, self.sentMid, @"msgID(%d) in SUBACK does not match msgID(%d) in SUBSCRIBE [MQTT-3.8.4-2]", self.mid, self.sentMid);
    for (NSNumber *qos in self.qoss) {
        XCTAssertEqual([qos intValue], 0x80, @"Returncode in SUBACK is not 0x80");
    }
}

- (void)testSubscribe:(NSString *)topic atLevel:(UInt8)qos
{
    self.sentMid = [self.session subscribeToTopic:topic atLevel:qos];
    [self performSelector:@selector(ackTimeout:)
               withObject:self.parameters[@"timeout"]
               afterDelay:[self.parameters[@"timeout"] intValue]];
     
    while (self.mid == 0 && !self.timeout && self.event == -1) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

- (void)testMultiSubscribe:(NSDictionary *)topics
{
    self.sentMid = [self.session subscribeToTopics:topics];
    [self performSelector:@selector(ackTimeout:)
               withObject:self.parameters[@"timeout"]
               afterDelay:[self.parameters[@"timeout"] intValue]];
     
    while (self.mid == 0 && !self.timeout && self.event == -1) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
}

- (void)testUnsubscribeTopic:(NSString *)topic
{
    self.sentMid = [self.session unsubscribeTopic:topic];
    [self performSelector:@selector(ackTimeout:)
               withObject:self.parameters[@"timeout"]
               afterDelay:[self.parameters[@"timeout"] intValue]];
     
    while (self.mid == 0 && !self.timeout && self.event == -1) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    XCTAssertFalse(self.timeout, @"No UNSUBACK received [MQTT-3.10.3-5] within %d seconds", 10);
    XCTAssertEqual(self.mid, self.sentMid, @"msgID(%d) in UNSUBACK does not match msgID(%d) in UNSUBSCRIBE [MQTT-3.10.3-4]", self.mid, self.sentMid);
}

- (void)testUnsubscribeTopicCloseExpected:(NSString *)topic
{
    self.sentMid = [self.session unsubscribeTopic:topic];
    [self performSelector:@selector(ackTimeout:)
               withObject:self.parameters[@"timeout"]
               afterDelay:[self.parameters[@"timeout"] intValue]];
     
    while (self.mid == 0 && !self.timeout && self.event == -1) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    XCTAssertFalse(self.timeout, @"No close within %d seconds", 10);
    XCTAssert(self.event == MQTTSessionEventConnectionClosed, @"Event %ld happened", (long)self.event);
}

- (void)testMultiUnsubscribeTopic:(NSArray *)topics
{
    self.sentMid = [self.session unsubscribeTopics:topics];
    [self performSelector:@selector(ackTimeout:)
               withObject:self.parameters[@"timeout"]
               afterDelay:[self.parameters[@"timeout"] intValue]];
     
    while (self.mid == 0 && !self.timeout && self.event == -1) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    XCTAssertFalse(self.timeout, @"No UNSUBACK received [MQTT-3.10.3-5] within %d seconds", 10);
    XCTAssertEqual(self.mid, self.sentMid, @"msgID(%d) in UNSUBACK does not match msgID(%d) in UNSUBSCRIBE [MQTT-3.10.3-4]", self.mid, self.sentMid);
}

- (void)ackTimeout:(NSTimeInterval)timeout
{
    self.timeout = TRUE;
}

- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(int)qos retained:(BOOL)retained mid:(unsigned int)mid
{
    NSLog(@"newMessage:%@ onTopic:%@ qos:%d retained:%d mid:%d", data, topic, qos, retained, mid);
}

- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error
{
    NSLog(@"handleEvent:%d error:%@", eventCode, error);
    self.event = eventCode;
}

- (void)subAckReceived:(MQTTSession *)session msgID:(UInt16)msgID grantedQoss:(NSArray *)qoss
{
    NSLog(@"subAckReceived:%d grantedQoss:%@", msgID, qoss);
    self.mid = msgID;
    self.qoss = qoss;
}

- (void)unsubAckReceived:(MQTTSession *)session msgID:(UInt16)msgID
{
    NSLog(@"unsubAckReceived:%d", msgID);
    self.mid = msgID;
}

- (void)received:(int)type qos:(int)qos retained:(BOOL)retained duped:(BOOL)duped mid:(UInt16)mid data:(NSData *)data
{
    NSLog(@"received:%d qos:%d retained:%d duped:%d mid:%d data:%@", type, qos, retained, duped, mid, data);
    
    self.type = type;
}



@end
