//
//  ZegoAVKitManager.m
//  LiveDemo
//
//  Copyright © 2015年 Zego. All rights reserved.
//

#include "ZegoAVKitManager.h"
#import "./advanced/video_capture_external_demo.h"
#import "./advanced/ZegoVideoCaptureFromImage.h"
#import "ZegoSettings.h"
#import "ZegoDataCenter.h"

static ZegoLiveRoomApi *g_ZegoApi = nil;

NSData *g_signKey = nil;
uint32_t g_appID = 0;


BOOL g_useTestEnv = NO;
BOOL g_useAlphaEnv = NO;

#if TARGET_OS_SIMULATOR
BOOL g_requireHardwareAccelerated = NO;
#else
BOOL g_requireHardwareAccelerated = YES;
#endif

BOOL g_enableVideoRateControl = NO;


static Byte toByte(NSString* c);
static NSData* ConvertStringToSign(NSString* strSign);

@interface ZegoInstantTalk ()

+ (void)setupVideoCaptureDevice;
+ (NSData *)zegoAppSignFromServer;

@end

@implementation ZegoInstantTalk

+ (ZegoLiveRoomApi *)api
{
    if (g_ZegoApi == nil)
    {
        [ZegoLiveRoomApi setUseTestEnv:g_useTestEnv];
        
#ifdef DEBUG
        [ZegoLiveRoomApi setVerbose:YES];
#endif
        
        [ZegoLiveRoomApi setUserID:[ZegoSettings sharedInstance].userID userName:[ZegoSettings sharedInstance].userName];
        [ZegoLiveRoomApi setBusinessType:2];
        [ZegoLiveRoomApi setUseChatRoom:YES];
        
        [self setupVideoCaptureDevice];
        
        NSData * appSign = [self zegoAppSignFromServer];
        g_ZegoApi = [[ZegoLiveRoomApi alloc] initWithAppID:[self appID] appSignature:appSign];
        
        if ([self appID] == 1739272706)
        {
            [g_ZegoApi setLatencyMode:ZEGOAPI_LATENCY_MODE_LOW];
        }
        
        [self setupHardwareAcceleratedAndRateControl];

    }
    
    return g_ZegoApi;
}

+ (void)releaseApi
{
    [[ZegoDataCenter sharedInstance] leaveRoom];
    
    g_ZegoApi = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RoomInstanceClear" object:nil userInfo:nil];
}

+ (void)setCustomAppID:(uint32_t)appid sign:(NSString *)sign
{
    g_appID = appid;
    NSData *d = ConvertStringToSign(sign);
    
    if (d.length == 32 && appid != 0)
    {
        g_appID = appid;
        g_signKey = [[NSData alloc] initWithData:d];
        
        [self releaseApi];
    }
}

+ (uint32_t)appID
{
    if (g_appID != 0)
    {
        return g_appID;
    }
    else
    {
#ifdef ZEGO_TEST_RTP3
#warning "ZEGO_TEST_RTP3"
        return 1739272706;  // * rtp
#else
#warning "ZEGO_DEMO"
        return 1;           // * demo
#endif
    }
}

+ (NSData *)zegoAppSignFromServer
{
    //!! Demo 把signKey先写到代码中
    //!! 规范用法：这个signKey需要从server下发到App，避免在App中存储，防止盗用
    
    if ([self appID] == 1)
    {
        Byte signkey[] = {0x91, 0x93, 0xcc, 0x66, 0x2a, 0x1c, 0x0e, 0xc1, 0x35, 0xec, 0x71, 0xfb, 0x07, 0x19, 0x4b, 0x38, 0x41, 0xd4, 0xad, 0x83, 0x78, 0xf2, 0x59, 0x90, 0xe0, 0xa4, 0x0c, 0x7f, 0xf4, 0x28, 0x41, 0xf7};
        return [NSData dataWithBytes:signkey length:32];
    }
    else if ([self appID] == 1739272706)
    {
        Byte signkey[] = {0x1e,0xc3,0xf8,0x5c,0xb2,0xf2,0x13,0x70,0x26,0x4e,0xb3,0x71,0xc8,0xc6,0x5c,0xa3,0x7f,0xa3,0x3b,0x9d,0xef,0xef,0x2a,0x85,0xe0,0xc8,0x99,0xae,0x82,0xc0,0xf6,0xf8};
        return [NSData dataWithBytes:signkey length:32];
    }
    else
    {
        return g_signKey;
    }
}

+ (void)setUsingTestEnv:(bool)testEnv
{
    if (g_useTestEnv != testEnv)
    {
        [self releaseApi];
    }
    
    g_useTestEnv = testEnv;
    [ZegoLiveRoomApi setUseTestEnv:testEnv];
}

+ (bool)usingTestEnv
{
    return g_useTestEnv;
}

+ (bool)usingAlphaEnv
{
    return g_useAlphaEnv;
}

+ (bool)usingExternalRender
{
    return false;
}

+ (void)setRequireHardwareAccelerated:(bool)hardwareAccelerated
{
    g_requireHardwareAccelerated = hardwareAccelerated;
    [self setupHardwareAcceleratedAndRateControl];
}

+ (bool)requireHardwareAccelerated
{
    return g_requireHardwareAccelerated;
}

#pragma mark - private

+ (void)setupVideoCaptureDevice
{
#if TARGET_OS_SIMULATOR
    static __strong id<ZegoVideoCaptureFactory> g_factory = nullptr;
    if (g_factory == nullptr) {
        g_factory = [[ZegoVideoCaptureFactory alloc] init];
        [ZegoLiveRoomApi setVideoCaptureFactory:g_factory];
    }
#else
    /*
     // try VideoCaptureFactoryDemo for camera
     static __strong id<ZegoVideoCaptureFactory> g_factory = nullptr;
     if (g_factory == nullptr)
     {
     g_factory = [[VideoCaptureFactoryDemo alloc] init];
     [ZegoLiveApi setVideoCaptureFactory:g_factory];
     }
     */
#endif
}

+ (void)setupHardwareAcceleratedAndRateControl
{
    [ZegoLiveRoomApi requireHardwareDecoder:g_requireHardwareAccelerated];
    [g_ZegoApi enableRateControl:g_enableVideoRateControl];

#ifdef ZEGO_TEST_RTP3
    // * rtp 不使用硬编
    [ZegoLiveRoomApi requireHardwareEncoder:false];
#else
    if (g_enableVideoRateControl)
    {
        // * 流控不使用硬编
        [ZegoLiveRoomApi requireHardwareEncoder:false];
    }
    else
    {
        [ZegoLiveRoomApi requireHardwareEncoder:g_requireHardwareAccelerated];
    }
#endif
}

@end

Byte toByte(NSString* c)
{
    NSString *str = @"0123456789abcdef";
    Byte b = [str rangeOfString:c].location;
    return b;
}

NSData* ConvertStringToSign(NSString* strSign)
{
    if(strSign == nil || strSign.length == 0)
        return nil;
    strSign = [strSign lowercaseString];
    strSign = [strSign stringByReplacingOccurrencesOfString:@" " withString:@""];
    strSign = [strSign stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    NSArray* szStr = [strSign componentsSeparatedByString:@","];
    int nLen = (int)[szStr count];
    Byte szSign[32];
    for(int i = 0; i < nLen; i++)
    {
        NSString *strTmp = [szStr objectAtIndex:i];
        if(strTmp.length == 1)
            szSign[i] = toByte(strTmp);
        else
        {
            szSign[i] = toByte([strTmp substringWithRange:NSMakeRange(0, 1)]) << 4 | toByte([strTmp substringWithRange:NSMakeRange(1, 1)]);
        }
        NSLog(@"%x,", szSign[i]);
    }
    
    NSData *sign = [NSData dataWithBytes:szSign length:32];
    return sign;
}

#pragma mark - alpha support

@interface NSObject()
// * suppress warning
+ (void)setUseAlphaEnv:(id)useAlphaEnv;
@end

@implementation ZegoInstantTalk (Alpha)

+ (void)setUsingAlphaEnv:(bool)alphaEnv
{
    if ([ZegoLiveRoomApi respondsToSelector:@selector(setUseAlphaEnv:)])
    {
        if (g_useAlphaEnv != alphaEnv)
        {
            [self releaseApi];
        }
        
        g_useAlphaEnv = alphaEnv;
        [ZegoLiveRoomApi performSelector:@selector(setUseAlphaEnv:) withObject:@(alphaEnv)];
    }
}

@end
