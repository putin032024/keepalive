// KeepAlive v2.3 — "bản ~2 tiếng" (ưu tiên SỐNG LÂU + đã nhận)
// Scene freeze + silent audio + relaunch khi chết
// Soft-wake ~40 phút (không wake 3 phút)
// 🟢 sống / 🔴 chết
// KHÔNG ép local banner (user: chỉ cần sống lâu như bản trước)

#import "KAConfig.h"
#import "Headers.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <notify.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

#pragma mark - Silent audio (IN APP)

static AVAudioPlayer *gPlayer;
static UIBackgroundTaskIdentifier gBg;
static BOOL gBgInit;
static NSTimer *gTimer;
static BOOL gStarted;

static void KAEnsureBgId(void) {
    if (!gBgInit) {
        gBg = UIBackgroundTaskInvalid;
        gBgInit = YES;
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
    @try {
        NSError *err = nil;
        AVAudioSession *s = [AVAudioSession sharedInstance];
        [s setCategory:AVAudioSessionCategoryPlayback
           withOptions:AVAudioSessionCategoryOptionMixWithOthers
                 error:&err];
        [s setActive:YES error:&err];
        if (!gPlayer) {
            gPlayer = [[AVAudioPlayer alloc] initWithData:KASilentWav() error:&err];
            gPlayer.numberOfLoops = -1;
            gPlayer.volume = 0.05;
        }
        if (gPlayer && !gPlayer.isPlaying) {
            [gPlayer prepareToPlay];
            [gPlayer play];
        }
        KABeginBg();
    } @catch (__unused NSException *e) {}
}

static void KATick(void) {
    if (![[KAConfig shared] isImmortal:[[NSBundle mainBundle] bundleIdentifier]])
        return;
    KAStartAudio();
}

static void KAStartIfNeeded(void) {
    [[KAConfig shared] reload];
    if (![[KAConfig shared] isImmortal:[[NSBundle mainBundle] bundleIdentifier]])
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        KATick();
        if (!gStarted) {
            gStarted = YES;
            gTimer = [NSTimer timerWithTimeInterval:12.0 repeats:YES
                block:^(__unused NSTimer *t) { KATick(); }];
            [[NSRunLoop mainRunLoop] addTimer:gTimer forMode:NSRunLoopCommonModes];
            [[NSNotificationCenter defaultCenter]
                addObserverForName:AVAudioSessionInterruptionNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *n) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ KATick(); });
            }];
            [[NSNotificationCenter defaultCenter]
                addObserverForName:UIApplicationDidEnterBackgroundNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *n) { KATick(); }];
        }
    });
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

static void KAOpenApp(NSString *bundle, NSString *reason) {
    if (!bundle.length) return;
    if ([KAPendingSet() containsObject:bundle]) return;
    [KAPendingSet() addObject:bundle];
    NSLog(@"[KeepAlive] open %@ (%@)", bundle, reason ?: @"?");
    BOOL urgent = [reason isEqualToString:@"dead"] || [reason isEqualToString:@"exit"];
    int64_t delay = urgent ? (int64_t)(0.2 * NSEC_PER_SEC) : (int64_t)(1.0 * NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^{
        [KAPendingSet() removeObject:bundle];
        if (![[KAConfig shared] isImmortal:bundle]) return;
        NSDictionary *opts = @{
            @"LSOpenApplicationOptionKeyActivateSuspended" : @YES,
            @"__ActivateSuspended" : @YES,
        };
        [[%c(FBSSystemService) sharedService]
            openApplication:bundle options:opts withResult:nil];
        if (urgent) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                if (![[KAConfig shared] isImmortal:bundle]) return;
                SBApplication *a = [[%c(SBApplicationController) sharedInstance]
                                    applicationWithBundleIdentifier:bundle];
                if (a.processState) return;
                [[%c(FBSSystemService) sharedService]
                    openApplication:bundle options:nil withResult:nil];
            });
        }
        [[KAConfig shared] refreshIcon:bundle];
        KALastWake()[bundle] = @([[NSDate date] timeIntervalSince1970]);
    });
}

static void KARelaunchIfDead(NSString *bundle) {
    if (!bundle.length) return;
    if (![[KAConfig shared] isImmortal:bundle]) return;
    SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                          applicationWithBundleIdentifier:bundle];
    if (app.processState != nil) return;
    KAOpenApp(bundle, @"dead");
}

// Soft-wake ~40 phút (kiểu bản sống lâu, không wake 3 phút)
static void KASoftWakeIfStale(NSString *bundle) {
    if (![[KAConfig shared] isImmortal:bundle]) return;
    SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                          applicationWithBundleIdentifier:bundle];
    if (app.processState == nil) {
        KARelaunchIfDead(bundle);
        return;
    }
    NSNumber *last = KALastWake()[bundle];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (last && (now - last.doubleValue) < 40 * 60) return;
    KAOpenApp(bundle, @"soft-wake-40m");
}

static void KAWatchdogTick(void) {
    if (![KAConfig shared].enabled) return;
    for (NSString *bid in [[KAConfig shared] immortalIDs]) {
        KARelaunchIfDead(bid);
        KASoftWakeIfStale(bid);
        [[KAConfig shared] refreshIcon:bid];
    }
}

// Scene freeze — giữ socket / đã nhận (bản ~2 tiếng)
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
- (long long)currentLabelAccessoryType {
    long long a = %orig;
    NSString *bid = [self.icon applicationBundleID];
    if ([[KAConfig shared] isImmortal:bid]) {
        SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                              applicationWithBundleIdentifier:bid];
        if (!app.processState)
            KARelaunchIfDead(bid);
    }
    return a;
}

- (NSArray *)applicationShortcutItems {
    NSArray *orig = %orig ?: @[];
    if (![KAConfig shared].enabled) return orig;
    NSString *bid = [self.icon applicationBundleID];
    if (!bid.length) return orig;
    BOOL on = [[KAConfig shared] isImmortal:bid];
    SBSApplicationShortcutItem *item = [[%c(SBSApplicationShortcutItem) alloc] init];
    item.localizedTitle = on ? @"Tắt KeepAlive" : @"Bật KeepAlive";
    item.localizedSubtitle = on ? @"🟢 sống / 🔴 chết (~2h+)" : @"Giữ Zalo2 sống lâu";
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
- (NSString *)displayName {
    NSString *n = %orig ?: @"";
    NSString *bid = self.bundleIdentifier;
    if (![[KAConfig shared] isImmortal:bid]) return n;
    n = [n stringByReplacingOccurrencesOfString:@" 🟢" withString:@""];
    n = [n stringByReplacingOccurrencesOfString:@" 🔴" withString:@""];
    n = [n stringByReplacingOccurrencesOfString:@"🟢" withString:@""];
    n = [n stringByReplacingOccurrencesOfString:@"🔴" withString:@""];
    n = [n stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (self.processState != nil)
        return [n stringByAppendingString:@" 🟢"];
    return [n stringByAppendingString:@" 🔴"];
}

- (void)_didExitWithContext:(id)arg1 {
    NSString *bid = self.bundleIdentifier;
    %orig;
    [[KAConfig shared] refreshIcon:bid];
    if ([[KAConfig shared] isImmortal:bid])
        KAOpenApp(bid, @"exit");
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

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    NSLog(@"[KeepAlive] v2.3 longevity mode (~2h, sound ok, no popup force)");
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:15.0 repeats:YES
            block:^(__unused NSTimer *t) { KAWatchdogTick(); }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ KAWatchdogTick(); });
    });
}
%end

%end // SpringBoardCore

#pragma mark - IN APP (audio only)

%group InApp

%hook UIApplication
- (void)setDelegate:(id)delegate {
    %orig;
    KAStartIfNeeded();
}
%end

%end

#pragma mark - ctor

static void KAPrefsCB(CFNotificationCenterRef c, void *o, CFStringRef n,
                      const void *obj, CFDictionaryRef i) {
    [[KAConfig shared] reload];
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"])
        KAStartIfNeeded();
}

%ctor {
    @autoreleasepool {
        [[KAConfig shared] reload];
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, KAPrefsCB,
            CFSTR(KA_NOTIFY_CSTR), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        if ([bid isEqualToString:@"com.apple.springboard"]) {
            %init(SpringBoardCore);
        } else {
            %init(InApp);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ KAStartIfNeeded(); });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ KAStartIfNeeded(); });
        }
    }
}
