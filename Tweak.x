// KeepAlive v2.0 — Zalo2 (đổi bundle) dual-IPA mode
// Mục tiêu: sống ~4 tiếng; 🟢 = đang sống; 🔴 = đã chết (mở lại app)
// Scene freeze + silent audio + relaunch + soft-wake ~45p

#import "KAConfig.h"
#import "Headers.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

static BOOL gFolder = NO;

#pragma mark - Silent audio keep-alive (IN APP)

static AVAudioPlayer *gPlayer;
static UIBackgroundTaskIdentifier gBg; // init 0 / Invalid
static NSTimer *gTimer;
static BOOL gAudioOn;
static BOOL gBgInited;

static void KAEnsureBgId(void) {
    if (!gBgInited) {
        gBg = UIBackgroundTaskInvalid;
        gBgInited = YES;
    }
}

static NSData *KASilentWav(void) {
    NSMutableData *d = [NSMutableData dataWithLength:44 + 800];
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
    uint32_t ds = 800;
    memcpy(b + 40, &ds, 4);
    memset(b + 44, 0x80, 800);
    return d;
}

static void KAEndBg(void) {
    KAEnsureBgId();
    if (gBg != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:gBg];
        gBg = UIBackgroundTaskInvalid;
    }
}

static void KABeginBg(void) {
    KAEnsureBgId();
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return;
    KAEndBg();
    gBg = [app beginBackgroundTaskWithName:@"KeepAlive" expirationHandler:^{
        KABeginBg();
    }];
}

static void KAStartAudio(void) {
    NSError *err = nil;
    AVAudioSession *s = [AVAudioSession sharedInstance];
    // Mix + không deactivate khi interrupted nếu có thể
    [s setCategory:AVAudioSessionCategoryPlayback
       withOptions:AVAudioSessionCategoryOptionMixWithOthers
             error:&err];
    [s setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&err];
    if (!gPlayer) {
        gPlayer = [[AVAudioPlayer alloc] initWithData:KASilentWav() error:&err];
        gPlayer.numberOfLoops = -1;
        gPlayer.volume = 0.05; // hơi to hơn 0.01 cho khó bị iOS coi silent-skip
    }
    if (gPlayer && !gPlayer.isPlaying) {
        [gPlayer prepareToPlay];
        [gPlayer play];
    }
    KABeginBg();
    gAudioOn = YES;
}

static void KAStopAudio(void) {
    [gPlayer stop];
    gPlayer = nil;
    KAEndBg();
    gAudioOn = NO;
}

static void KATick(void) {
    if (![[KAConfig shared] isImmortal:[[NSBundle mainBundle] bundleIdentifier]]) {
        if (gAudioOn) KAStopAudio();
        return;
    }
    KAStartAudio();
}

static void KAStartIfNeeded(void) {
    [[KAConfig shared] reload];
    NSString *me = [[NSBundle mainBundle] bundleIdentifier];
    if (![[KAConfig shared] isImmortal:me]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        KATick();
        if (!gTimer) {
            gTimer = [NSTimer timerWithTimeInterval:8.0 repeats:YES
                block:^(__unused NSTimer *t) { KATick(); }];
            [[NSRunLoop mainRunLoop] addTimer:gTimer forMode:NSRunLoopCommonModes];
        }
        // resume audio sau interrupt (cuộc gọi, app khác)
        [[NSNotificationCenter defaultCenter]
            addObserverForName:AVAudioSessionInterruptionNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ KATick(); });
        }];
    });
}

#pragma mark - Bundle id from notification request

static NSString *KAReqBundle(id req) {
    if (!req) return nil;
    @try {
        if ([req respondsToSelector:@selector(sectionIdentifier)]) {
            NSString *s = ((id (*)(id, SEL))objc_msgSend)(req, @selector(sectionIdentifier));
            if ([s isKindOfClass:[NSString class]] && s.length) return s;
        }
        if ([req respondsToSelector:@selector(bulletin)]) {
            id b = ((id (*)(id, SEL))objc_msgSend)(req, @selector(bulletin));
            if (b && [b respondsToSelector:@selector(sectionID)]) {
                NSString *s = ((id (*)(id, SEL))objc_msgSend)(b, @selector(sectionID));
                if ([s isKindOfClass:[NSString class]] && s.length) return s;
            }
        }
    } @catch (__unused id e) {}
    return nil;
}

#pragma mark - SPRINGBOARD

%group SpringBoardCore

static NSMutableSet *KAPendingSet(void) {
    static NSMutableSet *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [NSMutableSet new]; });
    return s;
}

static NSMutableDictionary *KALastWake(void) {
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary new]; });
    return d;
}

// Mở lại app — ưu tiên nhanh khi bị vuốt kill (miss notif lúc chết)
static void KAOpenApp(NSString *bundle, NSString *reason) {
    if (!bundle.length) return;
    if ([KAPendingSet() containsObject:bundle]) return;
    [KAPendingSet() addObject:bundle];
    NSLog(@"[KeepAlive] open %@ (%@)", bundle, reason ?: @"?");

    // dead = mở NGAY (vuốt nhầm); soft-wake = delay nhẹ
    BOOL urgent = [reason isEqualToString:@"dead"] || [reason isEqualToString:@"exit"];
    int64_t delayNs = urgent ? (int64_t)(0.15 * NSEC_PER_SEC) : (int64_t)(1.0 * NSEC_PER_SEC);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayNs),
                   dispatch_get_main_queue(), ^{
        [KAPendingSet() removeObject:bundle];
        if (![[KAConfig shared] isImmortal:bundle]) return;

        SBApplication *cur = [[%c(SBApplicationController) sharedInstance]
                              applicationWithBundleIdentifier:bundle];
        if (!urgent && cur.processState != nil) return;

        // Thử background trước; nếu fail vẫn open thường
        NSDictionary *bgOpts = @{
            @"LSOpenApplicationOptionKeyActivateSuspended" : @YES,
            @"__ActivateSuspended" : @YES,
            @"LSOpenApplicationOptionKeyForBackgroundFetch" : @YES,
        };
        [[%c(FBSSystemService) sharedService]
            openApplication:bundle options:bgOpts withResult:nil];

        // double-tap: 0.8s sau vẫn chết thì open full (đảm bảo sống lại)
        if (urgent) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (![[KAConfig shared] isImmortal:bundle]) return;
                SBApplication *a2 = [[%c(SBApplicationController) sharedInstance]
                                     applicationWithBundleIdentifier:bundle];
                if (a2.processState != nil) return;
                NSLog(@"[KeepAlive] retry full open %@", bundle);
                [[%c(FBSSystemService) sharedService]
                    openApplication:bundle options:nil withResult:nil];
                [[KAConfig shared] refreshIcon:bundle];
            });
        }

        [[KAConfig shared] refreshIcon:bundle];
        KALastWake()[bundle] = @([[NSDate date] timeIntervalSince1970]);
    });
}

// Process chết hẳn (chấm vàng / vuốt kill)
static void KARelaunchIfDead(NSString *bundle) {
    if (!bundle.length) return;
    KAConfig *cfg = [KAConfig shared];
    if (!cfg.enabled || ![cfg isImmortal:bundle]) return;
    SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                          applicationWithBundleIdentifier:bundle];
    if (app.processState != nil) return;
    KAOpenApp(bundle, @"dead");
}

// Soft-wake ~45 phút/lần để kéo socket ~4 tiếng (trước khi tịt)
static void KASoftWakeIfStale(NSString *bundle) {
    if (!bundle.length) return;
    KAConfig *cfg = [KAConfig shared];
    if (!cfg.enabled || ![cfg isImmortal:bundle]) return;
    SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                          applicationWithBundleIdentifier:bundle];
    if (app.processState == nil) {
        KARelaunchIfDead(bundle);
        return;
    }
    NSNumber *last = KALastWake()[bundle];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    // 45 phút soft-wake: 45/90/135/180/225… → hỗ trợ ~4h+
    if (last && (now - last.doubleValue) < 45 * 60) return;
    KAOpenApp(bundle, @"soft-wake-45m");
}

static void KARefreshAllIcons(void) {
    for (NSString *bid in [[KAConfig shared] immortalIDs]) {
        [[KAConfig shared] refreshIcon:bid];
    }
}

static void KAWatchdogTick(void) {
    KAConfig *cfg = [KAConfig shared];
    if (!cfg.enabled) return;
    for (NSString *bid in [cfg immortalIDs]) {
        KARelaunchIfDead(bid);
        KASoftWakeIfStale(bid);
    }
    KARefreshAllIcons(); // cập nhật 🟢/🔴
}

// === Immortalizer-style: chặn deactivate scene (giữ sống lâu hơn audio-only) ===
%hook FBScene
- (void)updateSettings:(id)arg1 withTransitionContext:(id)arg2 completion:(id)arg3 {
    FBProcess *p = self.clientProcess;
    if (p && [[KAConfig shared] isImmortal:p.bundleIdentifier] && arg2 == nil) {
        [[KAConfig shared] refreshIcon:p.bundleIdentifier];
        return;
    }
    %orig;
}
%end

%hook UIMutableApplicationSceneSettings
- (void)setDeactivationReasons:(unsigned long long)arg1 {
    if (arg1 != 0 && [KAConfig shared].enabled && [KAConfig shared].immortalIDs.count > 0)
        return;
    %orig;
}
%end

%hook SBIconView
// Không dùng hourglass/chấm vàng — dùng 🟢/🔴 trên tên (rõ hơn)
- (long long)currentLabelAccessoryType {
    long long a = %orig;
    KAConfig *c = [KAConfig shared];
    NSString *bid = [self.icon applicationBundleID];
    if (c.enabled && bid && [c isImmortal:bid]) {
        SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                              applicationWithBundleIdentifier:bid];
        if (!app.processState)
            KARelaunchIfDead(bid);
        // giữ accessory gốc, status = emoji trên displayName
    }
    return a;
}

- (NSArray *)applicationShortcutItems {
    NSArray *orig = %orig ?: @[];
    if (![KAConfig shared].enabled) return orig;
    NSString *bid = nil;
    if ([self.icon respondsToSelector:@selector(applicationBundleID)])
        bid = [self.icon applicationBundleID];
    if (!bid.length) return orig;

    BOOL on = [[KAConfig shared] isImmortal:bid];
    SBSApplicationShortcutItem *item = [[%c(SBSApplicationShortcutItem) alloc] init];
    item.localizedTitle = on ? @"Tắt KeepAlive" : @"Bật KeepAlive";
    item.localizedSubtitle = on ? @"🟢 sống / 🔴 chết — ~4h" : @"Giữ Zalo2 sống ~4h";
    item.type = KA_SHORTCUT;
    item.bundleIdentifierToLaunch = bid;
    return [orig arrayByAddingObject:item];
}

+ (void)activateShortcut:(SBSApplicationShortcutItem *)item
    withBundleIdentifier:(NSString *)bundleID
             forIconView:(id)iconView {
    if (item && [item.type isEqualToString:KA_SHORTCUT]) {
        NSString *bid = bundleID ?: item.bundleIdentifierToLaunch;
        [[KAConfig shared] toggleImmortal:bid];
        if ([[KAConfig shared] isImmortal:bid])
            KALastWake()[bid] = @([[NSDate date] timeIntervalSince1970]);
        return;
    }
    %orig;
}
%end

%hook SBApplication
// 🟢 = process sống (đang KeepAlive); 🔴 = chết hẳn → vào mở lại
- (NSString *)displayName {
    NSString *n = %orig ?: @"";
    NSString *bid = self.bundleIdentifier;
    if (![[KAConfig shared] isImmortal:bid]) return n;

    // tránh cộng dồn emoji
    n = [n stringByReplacingOccurrencesOfString:@" 🟢" withString:@""];
    n = [n stringByReplacingOccurrencesOfString:@" 🔴" withString:@""];
    n = [n stringByReplacingOccurrencesOfString:@"🟢" withString:@""];
    n = [n stringByReplacingOccurrencesOfString:@"🔴" withString:@""];
    n = [n stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

    if (self.processState != nil)
        return [n stringByAppendingString:@" 🟢"];
    return [n stringByAppendingString:@" 🔴"];
}

- (long long)labelAccessoryTypeForIcon:(id)arg1 {
    long long a = %orig;
    if ([[KAConfig shared] isImmortal:self.bundleIdentifier] && !self.processState)
        KARelaunchIfDead(self.bundleIdentifier);
    return a;
}

- (void)_didExitWithContext:(id)arg1 {
    NSString *bid = self.bundleIdentifier;
    %orig;
    [[KAConfig shared] refreshIcon:bid];
    if ([[KAConfig shared] isImmortal:bid]) {
        NSLog(@"[KeepAlive] %@ EXIT — relaunch + 🔴", bid);
        KAOpenApp(bid, @"exit");
    }
}
%end

%hook SBFluidSwitcherItemContainer
- (void)setKillable:(BOOL)arg1 {
    BOOL k = arg1;
    if ([KAConfig shared].enabled) {
        SBAppLayout *layout = [self appLayout];
        NSDictionary *map = nil;
        if (@available(iOS 16.0, *))
            map = layout.itemsToLayoutAttributesMap;
        else {
            Ivar iv = class_getInstanceVariable(object_getClass(layout), "_rolesToLayoutItemsMap");
            if (iv) map = object_getIvar(layout, iv);
        }
        if (map) {
            if (@available(iOS 16.0, *)) {
                for (SBDisplayItem *it in map)
                    if ([[KAConfig shared] isImmortal:it.bundleIdentifier]) k = NO;
            } else {
                SBDisplayItem *it = map[@1];
                if ([it respondsToSelector:@selector(bundleIdentifier)] &&
                    [[KAConfig shared] isImmortal:it.bundleIdentifier])
                    k = NO;
            }
        }
    }
    %orig(k);
}
%end

// Force system banners (khi có system notification)
%hook UNSUserNotificationServer
- (BOOL)_isApplicationForeground:(NSString *)bundle {
    if (bundle && [[KAConfig shared] isImmortal:bundle]) return NO;
    return %orig;
}
- (BOOL)isApplicationForeground:(NSString *)bundle {
    if (bundle && [[KAConfig shared] isImmortal:bundle]) return NO;
    return %orig;
}
- (void)willPresentNotification:(id)notif
            forBundleIdentifier:(NSString *)bundle
          withCompletionHandler:(id)handler {
    if (bundle && [[KAConfig shared] isImmortal:bundle]) {
        [self _didChangeApplicationState:4 forBundleIdentifier:bundle];
        void (^origH)(NSUInteger) = handler;
        void (^forcedH)(NSUInteger) = ^(NSUInteger options) {
            if (origH) origH(options | KA_PRESENT_ALL);
        };
        %orig(notif, bundle, forcedH);
        return;
    }
    %orig;
}
%end

%hook SBNotificationBannerDestination
- (BOOL)canReceiveNotificationRequest:(id)req {
    NSString *bid = KAReqBundle(req);
    if (bid && [[KAConfig shared] isImmortal:bid]) return YES;
    return %orig;
}
%end

%hook UNSApplicationForegroundMonitor
- (BOOL)isApplicationForeground:(NSString *)bundle {
    if (bundle && [[KAConfig shared] isImmortal:bundle]) return NO;
    return %orig;
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    NSLog(@"[KeepAlive] v2.0 dual-IPA: 🟢/🔴 + ~4h soft-wake 45m");
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:YES
            block:^(__unused NSTimer *t) { KAWatchdogTick(); }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ KAWatchdogTick(); });
    });
}
%end

%end // SpringBoardCore

#pragma mark - IN APP: audio + force willPresent banner

%group InApp

static NSMutableSet *KASwizzled(void) {
    static NSMutableSet *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [NSMutableSet new]; });
    return s;
}
static void (*KAOrigWP)(id, SEL, id, id, void (^)(NSUInteger)) = NULL;
static void KAHookedWP(id self, SEL _cmd, UNUserNotificationCenter *c,
                       UNNotification *n, void (^completion)(NSUInteger)) {
    void (^wrap)(NSUInteger) = ^(NSUInteger o) {
        if (completion) completion(o | KA_PRESENT_ALL);
    };
    if (KAOrigWP) KAOrigWP(self, _cmd, c, n, wrap);
    else if (completion) completion(KA_PRESENT_ALL);
}
static void KASwizzle(id delegate) {
    if (!delegate) return;
    Class cls = object_getClass(delegate);
    NSString *name = NSStringFromClass(cls);
    if ([KASwizzled() containsObject:name]) return;
    SEL sel = @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    KAOrigWP = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)KAHookedWP);
    [KASwizzled() addObject:name];
}

%hook UNUserNotificationCenter
- (void)setDelegate:(id)d {
    KASwizzle(d);
    %orig;
}
- (id)delegate {
    id d = %orig;
    KASwizzle(d);
    return d;
}
%end

%hook UIApplication
- (void)setDelegate:(id)delegate {
    %orig;
    KAStartIfNeeded();
}
%end

%end // InApp

#pragma mark - ctor

static void KAPrefsCB(CFNotificationCenterRef c, void *o, CFStringRef n,
                      const void *obj, CFDictionaryRef i) {
    [[KAConfig shared] reload];
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if (![bid isEqualToString:@"com.apple.springboard"])
        KAStartIfNeeded();
}

%ctor {
    @autoreleasepool {
        [[KAConfig shared] reload];
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, KAPrefsCB,
            CFSTR(KA_NOTIFY_CSTR), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSLog(@"[KeepAlive] load in %@", bid);

        if ([bid isEqualToString:@"com.apple.springboard"]) {
            %init(SpringBoardCore);
        } else {
            %init(InApp);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ KAStartIfNeeded(); });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                KASwizzle([UNUserNotificationCenter currentNotificationCenter].delegate);
                KAStartIfNeeded();
            });
        }
    }
}
