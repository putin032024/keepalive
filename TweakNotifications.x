// TweakNotifications.x — ÉP HIỆN POPUP / BANNER
// SpringBoard: UNSUserNotificationServer
// App: wrap UNUserNotificationCenter delegate willPresent

#import "AAConfig.h"
#import "Headers.h"
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>

// Badge|Sound|Alert|List|Banner
#ifndef AA_PRESENT_ALL
#define AA_PRESENT_ALL (1 | 2 | 4 | 8 | 16)
#endif

#pragma mark - SpringBoard server

%group SpringBoardNotifs

%hook UNSUserNotificationServer

- (void)willPresentNotification:(id)notif
            forBundleIdentifier:(NSString *)bundle
          withCompletionHandler:(id)handler {

    AAConfig *cfg = [AAConfig shared];
    BOOL force = cfg.enabled && cfg.forceBanner && bundle.length
                 && [cfg isImmortal:bundle];

    if (force) {
        // Coi app không foreground → SpringBoard cho banner
        [self _didChangeApplicationState:4 forBundleIdentifier:bundle];

        void (^origHandler)(NSUInteger) = handler;
        void (^forcedHandler)(NSUInteger) = ^(NSUInteger options) {
            NSUInteger out = options | (NSUInteger)AA_PRESENT_ALL;
            if (origHandler) origHandler(out);
        };

        %orig(notif, bundle, forcedHandler);
        return;
    }

    %orig;
}

%end

%end

#pragma mark - App process: safe delegate wrap

%group AppNotifs

static NSMutableSet *AASwizzledClasses(void) {
    static NSMutableSet *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [NSMutableSet new]; });
    return s;
}

static void (*AAOrigWillPresent)(id, SEL, id, id, void (^)(NSUInteger)) = NULL;

static void AAHookedWillPresent(id self, SEL _cmd,
                                UNUserNotificationCenter *center,
                                UNNotification *notification,
                                void (^completion)(NSUInteger)) {
    void (^forced)(NSUInteger) = ^(NSUInteger options) {
        if (completion) completion(options | (NSUInteger)AA_PRESENT_ALL);
    };
    if (AAOrigWillPresent) {
        AAOrigWillPresent(self, _cmd, center, notification, forced);
    } else if (completion) {
        completion((NSUInteger)AA_PRESENT_ALL);
    }
}

static void AASwizzleDelegate(id delegate) {
    if (!delegate) return;
    // Prefs: mặc định ép nếu không đọc được suite
    NSUserDefaults *p = [[NSUserDefaults alloc] initWithSuiteName:AA_PREFS_SUITE];
    BOOL enabled = [p objectForKey:AA_KEY_ENABLED] ? [p boolForKey:AA_KEY_ENABLED] : YES;
    BOOL force = [p objectForKey:AA_KEY_FORCE_BANNER] ? [p boolForKey:AA_KEY_FORCE_BANNER] : YES;
    if (!enabled || !force) return;

    Class cls = object_getClass(delegate);
    NSString *name = NSStringFromClass(cls);
    if ([AASwizzledClasses() containsObject:name]) return;

    SEL sel = @selector(userNotificationCenter:willPresentNotification:withCompletionHandler:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    AAOrigWillPresent = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)AAHookedWillPresent);
    [AASwizzledClasses() addObject:name];
}

%hook UNUserNotificationCenter

- (void)setDelegate:(id)delegate {
    AASwizzleDelegate(delegate);
    %orig;
}

- (id)delegate {
    id d = %orig;
    AASwizzleDelegate(d);
    return d;
}

%end

%end

%ctor {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if ([bid isEqualToString:@"com.apple.springboard"]) {
        %init(SpringBoardNotifs);
    } else {
        %init(AppNotifs);
        // Delegate có thể set trước khi dylib load — quét sau 2s
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UNUserNotificationCenter *c = [UNUserNotificationCenter currentNotificationCenter];
            AASwizzleDelegate(c.delegate);
        });
    }
}
