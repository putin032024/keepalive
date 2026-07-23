// ForceBanner — CHẠY CÙNG Immortalizer (KHÔNG tắt Immortalizer)
// Immortalizer: giữ app sống
// Tweak này:     ÉP hiện popup/banner (hết chỉ-có-tiếng)
//
// List app immortal đọc từ Immortalizer:
//   NSUserDefaults key: ImmortalForegroundBundleIDs

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#import <notify.h>

// Prefs suite riêng
#define FB_PREFS @"com.local.forcebanner.prefs"
#define FB_KEY_ENABLED @"enabled"
#define FB_KEY_ONLY_IMMORTAL @"onlyImmortal"   // YES = chỉ app Immortalizer đang immortal
#define FB_KEY_FORCE_ALL @"forceAll"           // YES = ép mọi app
#define FB_NOTIFY @"com.local.forcebanner.prefschanged"

// Immortalizer list
#define IMM_KEY @"ImmortalForegroundBundleIDs"

// UNNotificationPresentationOptions: Badge|Sound|Alert|List|Banner
#define FB_PRESENT_ALL (1u | 2u | 4u | 8u | 16u)

static BOOL gEnabled = YES;
static BOOL gOnlyImmortal = YES;
static BOOL gForceAll = NO;

static void FBReload(void) {
    NSUserDefaults *p = [[NSUserDefaults alloc] initWithSuiteName:FB_PREFS];
    gEnabled = [p objectForKey:FB_KEY_ENABLED] ? [p boolForKey:FB_KEY_ENABLED] : YES;
    gOnlyImmortal = [p objectForKey:FB_KEY_ONLY_IMMORTAL] ? [p boolForKey:FB_KEY_ONLY_IMMORTAL] : YES;
    gForceAll = [p objectForKey:FB_KEY_FORCE_ALL] ? [p boolForKey:FB_KEY_FORCE_ALL] : NO;
}

static BOOL FBIsImmortal(NSString *bundle) {
    if (!bundle.length) return NO;
    NSArray *ids = [[NSUserDefaults standardUserDefaults] arrayForKey:IMM_KEY];
    return [ids containsObject:bundle];
}

static BOOL FBShouldForce(NSString *bundle) {
    if (!gEnabled) return NO;
    if (gForceAll) return YES;
    if (gOnlyImmortal) return FBIsImmortal(bundle);
    return YES;
}

#pragma mark - SpringBoard: ép banner khi notif tới

@interface UNSUserNotificationServer : NSObject
+ (id)sharedInstance;
- (void)_didChangeApplicationState:(unsigned)state forBundleIdentifier:(NSString *)bundle;
@end

%group SpringBoard

%hook UNSUserNotificationServer

- (void)willPresentNotification:(id)notif
            forBundleIdentifier:(NSString *)bundle
          withCompletionHandler:(id)handler {

    if (FBShouldForce(bundle)) {
        // Immortalizer giữ foreground → iOS nuốt banner
        // Tạm coi app "không foreground" + ép options banner
        [self _didChangeApplicationState:4 forBundleIdentifier:bundle];

        void (^orig)(NSUInteger) = handler;
        void (^forced)(NSUInteger) = ^(NSUInteger options) {
            if (orig) orig(options | FB_PRESENT_ALL);
        };
        %orig(notif, bundle, forced);
        return;
    }
    %orig;
}

%end

%end

#pragma mark - Trong app: willPresent hay return 0 → ép banner

%group InApp

static NSMutableSet *FBSwizzled(void) {
    static NSMutableSet *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [NSMutableSet new]; });
    return s;
}

static void (*FBOrigWillPresent)(id, SEL, id, id, void (^)(NSUInteger)) = NULL;

static void FBHookedWillPresent(id self, SEL _cmd,
                                UNUserNotificationCenter *center,
                                UNNotification *notification,
                                void (^completion)(NSUInteger)) {
    void (^wrap)(NSUInteger) = ^(NSUInteger options) {
        if (completion) completion(options | FB_PRESENT_ALL);
    };
    if (FBOrigWillPresent)
        FBOrigWillPresent(self, _cmd, center, notification, wrap);
    else if (completion)
        completion(FB_PRESENT_ALL);
}

static void FBSwizzleDelegate(id delegate) {
    if (!delegate || !gEnabled) return;
    // Trong app: nếu onlyImmortal, check bundle hiện tại
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (!FBShouldForce(bid) && !gForceAll) {
        // standardUserDefaults trong sandbox app có thể KHÔNG thấy ImmortalForegroundBundleIDs
        // → nếu onlyImmortal: vẫn ép khi forceBanner bật + enabled (an toàn hơn miss popup)
        // Đổi: trong app process luôn ép nếu gEnabled (prefs)
        if (!gEnabled) return;
        // tiếp tục ép nếu enabled — Immortalizer đang bật thì app này thường là immortal
        if (gOnlyImmortal && !gForceAll) {
            // cố đọc list; không có thì vẫn ép (tránh miss)
        }
    }

    Class cls = object_getClass(delegate);
    NSString *name = NSStringFromClass(cls);
    if ([FBSwizzled() containsObject:name]) return;

    SEL sel = @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    FBOrigWillPresent = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)FBHookedWillPresent);
    [FBSwizzled() addObject:name];
}

%hook UNUserNotificationCenter

- (void)setDelegate:(id)delegate {
    FBSwizzleDelegate(delegate);
    %orig;
}

- (id)delegate {
    id d = %orig;
    FBSwizzleDelegate(d);
    return d;
}

%end

%end

#pragma mark - ctor

static void FBPrefsChanged(CFNotificationCenterRef c, void *o, CFStringRef n,
                           const void *obj, CFDictionaryRef i) {
    FBReload();
}

%ctor {
    FBReload();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        FBPrefsChanged, CFSTR(FB_NOTIFY), NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);

    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if ([bid isEqualToString:@"com.apple.springboard"]) {
        %init(SpringBoard);
    } else {
        %init(InApp);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            FBSwizzleDelegate([UNUserNotificationCenter currentNotificationCenter].delegate);
        });
    }
}
