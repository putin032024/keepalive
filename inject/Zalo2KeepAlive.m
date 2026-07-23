// Zalo2KeepAlive inject — silent audio + LOCAL BANNER khi badge tăng
// (fix lỗi chỉ tiếng, không popup)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define Z2_PRESENT (1u | 2u | 4u | 8u | 16u)

static AVAudioPlayer *gPlayer;
static UIBackgroundTaskIdentifier gBg;
static BOOL gBgInit;
static NSTimer *gTimer;
static BOOL gStarted;
static NSTimeInterval gLastBanner;
static void (*Z2OrigSetBadge)(id, SEL, NSInteger);

static void Z2EnsureBg(void) {
    if (!gBgInit) { gBg = UIBackgroundTaskInvalid; gBgInit = YES; }
}

static NSData *Z2SilentWav(void) {
    NSMutableData *d = [NSMutableData dataWithLength:44 + 1600];
    uint8_t *b = (uint8_t *)d.mutableBytes;
    memset(b, 0, d.length);
    memcpy(b, "RIFF", 4);
    uint32_t riff = (uint32_t)(d.length - 8);
    memcpy(b + 4, &riff, 4);
    memcpy(b + 8, "WAVEfmt ", 8);
    uint32_t fmt = 16;
    memcpy(b + 16, &fmt, 4);
    uint16_t af = 1, ch = 1, bits = 8, ba = 1;
    uint32_t sr = 8000, br = 8000;
    memcpy(b + 20, &af, 2);
    memcpy(b + 22, &ch, 2);
    memcpy(b + 24, &sr, 4);
    memcpy(b + 28, &br, 4);
    memcpy(b + 32, &ba, 2);
    memcpy(b + 34, &bits, 2);
    memcpy(b + 36, "data", 4);
    uint32_t ds = 1600;
    memcpy(b + 40, &ds, 4);
    memset(b + 44, 0x80, 1600);
    return d;
}

static void Z2EndBg(void) {
    Z2EnsureBg();
    if (gBg != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:gBg];
        gBg = UIBackgroundTaskInvalid;
    }
}

static void Z2BeginBg(void) {
    Z2EnsureBg();
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return;
    Z2EndBg();
    gBg = [app beginBackgroundTaskWithName:@"Zalo2KeepAlive" expirationHandler:^{ Z2BeginBg(); }];
}

static void Z2StartAudio(void) {
    @try {
        NSError *err = nil;
        AVAudioSession *s = [AVAudioSession sharedInstance];
        [s setCategory:AVAudioSessionCategoryPlayback
           withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&err];
        [s setActive:YES error:&err];
        if (!gPlayer) {
            gPlayer = [[AVAudioPlayer alloc] initWithData:Z2SilentWav() error:&err];
            gPlayer.numberOfLoops = -1;
            gPlayer.volume = 0.05;
        }
        if (gPlayer && !gPlayer.isPlaying) {
            [gPlayer prepareToPlay];
            [gPlayer play];
        }
        Z2BeginBg();
    } @catch (__unused NSException *e) {}
}

static void Z2Tick(void) { Z2StartAudio(); }

static void Z2PostBanner(NSString *body) {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - gLastBanner < 1.2) return;
    gLastBanner = now;

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:
        (UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
        completionHandler:^(__unused BOOL g, __unused NSError *e) {}];

    UNMutableNotificationContent *c = [UNMutableNotificationContent new];
    NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!name.length) name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    c.title = name.length ? name : @"Zalo";
    c.body = body.length ? body : @"Bạn có tin nhắn mới";
    c.sound = [UNNotificationSound defaultSound];

    UNTimeIntervalNotificationTrigger *tr =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.15 repeats:NO];
    UNNotificationRequest *req = [UNNotificationRequest
        requestWithIdentifier:[[NSUUID UUID] UUIDString] content:c trigger:tr];
    [center addNotificationRequest:req withCompletionHandler:nil];
    NSLog(@"[Zalo2KeepAlive] local banner");
}

static void Z2Start(void) {
    if (gStarted) { Z2Tick(); return; }
    gStarted = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        Z2Tick();
        if (!gTimer) {
            gTimer = [NSTimer timerWithTimeInterval:8.0 repeats:YES
                block:^(__unused NSTimer *t) { Z2Tick(); }];
            [[NSRunLoop mainRunLoop] addTimer:gTimer forMode:NSRunLoopCommonModes];
        }
        [[NSNotificationCenter defaultCenter]
            addObserverForName:AVAudioSessionInterruptionNotification object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(__unused NSNotification *n) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ Z2Tick(); });
            }];
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(__unused NSNotification *n) { Z2Tick(); }];
        NSLog(@"[Zalo2KeepAlive] started %@", [[NSBundle mainBundle] bundleIdentifier]);
    });
}

static NSMutableSet *Z2Swizzled(void) {
    static NSMutableSet *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [NSMutableSet new]; });
    return s;
}
static void (*Z2OrigWP)(id, SEL, id, id, void (^)(NSUInteger)) = NULL;
static void Z2HookedWP(id self, SEL _cmd, UNUserNotificationCenter *c,
                       UNNotification *n, void (^completion)(NSUInteger)) {
    void (^wrap)(NSUInteger) = ^(NSUInteger o) {
        if (completion) completion(o | Z2_PRESENT);
    };
    if (Z2OrigWP) Z2OrigWP(self, _cmd, c, n, wrap);
    else if (completion) completion(Z2_PRESENT);
}
static void Z2SwizzleDelegate(id delegate) {
    if (!delegate) return;
    Class cls = object_getClass(delegate);
    NSString *name = NSStringFromClass(cls);
    if ([Z2Swizzled() containsObject:name]) return;
    SEL sel = @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    Z2OrigWP = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)Z2HookedWP);
    [Z2Swizzled() addObject:name];
}

static void Z2HookedSetBadge(id self, SEL _cmd, NSInteger n) {
    NSInteger old = [self applicationIconBadgeNumber];
    if (Z2OrigSetBadge) Z2OrigSetBadge(self, _cmd, n);
    else ((void (*)(id, SEL, NSInteger))objc_msgSend)(self, @selector(setApplicationIconBadgeNumber:), n);
    if (n > old && n > 0)
        Z2PostBanner([NSString stringWithFormat:@"(%ld) tin nhắn mới", (long)n]);
}

static void (*Z2OrigSetDel)(id, SEL, id) = NULL;
static void Z2HookedSetDel(id self, SEL _cmd, id del) {
    if (Z2OrigSetDel) Z2OrigSetDel(self, _cmd, del);
    Z2Start();
}

static void Z2Install(void) {
    Class app = objc_getClass("UIApplication");
    Method setDel = class_getInstanceMethod(app, @selector(setDelegate:));
    if (setDel) {
        Z2OrigSetDel = (void *)method_getImplementation(setDel);
        method_setImplementation(setDel, (IMP)Z2HookedSetDel);
    }
    Method badge = class_getInstanceMethod(app, @selector(setApplicationIconBadgeNumber:));
    if (badge) {
        Z2OrigSetBadge = (void *)method_getImplementation(badge);
        method_setImplementation(badge, (IMP)Z2HookedSetBadge);
    }
    Class unc = objc_getClass("UNUserNotificationCenter");
    Method m = class_getInstanceMethod(unc, @selector(setDelegate:));
    if (m) {
        IMP old = method_getImplementation(m);
        IMP hook = imp_implementationWithBlock(^(id self, id del) {
            ((void (*)(id, SEL, id))old)(self, @selector(setDelegate:), del);
            Z2SwizzleDelegate(del);
        });
        method_setImplementation(m, hook);
    }
}

__attribute__((constructor))
static void Zalo2KeepAliveInit(void) {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
        if ([bid isEqualToString:@"com.apple.springboard"]) return;
        NSLog(@"[Zalo2KeepAlive] load %@", bid);
        Z2Install();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Z2Start();
            Z2SwizzleDelegate([UNUserNotificationCenter currentNotificationCenter].delegate);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Z2Start();
            Z2SwizzleDelegate([UNUserNotificationCenter currentNotificationCenter].delegate);
        });
    }
}
