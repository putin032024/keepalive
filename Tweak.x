// KeepAlive v1.5
// Giữ process: SILENT AUDIO + background task (app VẪN background)
// → iOS/Zalo vẫn post system notification → có banner
// KHÔNG fake full-foreground scene (cái đó = chỉ tiếng, không popup)

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
static UIBackgroundTaskIdentifier gBg = UIBackgroundTaskInvalid;
static NSTimer *gTimer;
static BOOL gAudioOn;

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
    if (gBg != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:gBg];
        gBg = UIBackgroundTaskInvalid;
    }
}

static void KABeginBg(void) {
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
    [s setCategory:AVAudioSessionCategoryPlayback
       withOptions:AVAudioSessionCategoryOptionMixWithOthers
             error:&err];
    [s setActive:YES error:&err];
    if (!gPlayer) {
        gPlayer = [[AVAudioPlayer alloc] initWithData:KASilentWav() error:&err];
        gPlayer.numberOfLoops = -1;
        gPlayer.volume = 0.01;
    }
    if (gPlayer && !gPlayer.isPlaying) {
        [gPlayer prepareToPlay];
        [gPlayer play];
    }
    KABeginBg();
    gAudioOn = YES;
    NSLog(@"[KeepAlive] silent audio keep-alive ON (%@)",
          [[NSBundle mainBundle] bundleIdentifier]);
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
            gTimer = [NSTimer timerWithTimeInterval:15.0 repeats:YES
                block:^(__unused NSTimer *t) { KATick(); }];
            [[NSRunLoop mainRunLoop] addTimer:gTimer forMode:NSRunLoopCommonModes];
        }
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

#pragma mark - SPRINGBOARD: menu + lock kill + force banner
// KHÔNG chặn FBScene deactivate nữa → app background → có system banner

%group SpringBoardCore

// --- bỏ FBScene freeze (đây là nguyên nhân chỉ-có-tiếng) ---

%hook SBIconView
- (long long)currentLabelAccessoryType {
    long long a = %orig;
    KAConfig *c = [KAConfig shared];
    if (!c.enabled) return a;
    NSString *bid = [self.icon applicationBundleID];
    if (bid && [c isImmortal:bid]) {
        SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                              applicationWithBundleIdentifier:bid];
        a = app.processState ? 4 : 2;
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
    item.localizedSubtitle = on ? @"Đang giữ nền (audio)" : @"Giữ nền + banner";
    item.type = KA_SHORTCUT;
    item.bundleIdentifierToLaunch = bid;
    return [orig arrayByAddingObject:item];
}

+ (void)activateShortcut:(SBSApplicationShortcutItem *)item
    withBundleIdentifier:(NSString *)bundleID
             forIconView:(id)iconView {
    if (item && [item.type isEqualToString:KA_SHORTCUT]) {
        [[KAConfig shared] toggleImmortal:bundleID ?: item.bundleIdentifierToLaunch];
        return;
    }
    %orig;
}
%end

%hook SBApplication
- (long long)labelAccessoryTypeForIcon:(id)arg1 {
    long long a = %orig;
    if ([[KAConfig shared] isImmortal:self.bundleIdentifier])
        a = self.processState ? 4 : 2;
    return a;
}
- (void)_didExitWithContext:(id)arg1 {
    %orig;
    [[KAConfig shared] refreshIcon:self.bundleIdentifier];
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
    NSLog(@"[KeepAlive] SB ready — audio keep-alive mode (no scene-freeze)");
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
- (void)setDelegate:(id)d { KASwizzle(d); %orig; }
- (id)delegate { id d = %orig; KASwizzle(d); return d; }
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
