// KeepAlive — immortal + force popup
// Load OK: hiện toast "KeepAlive OK" trên SpringBoard (biết dylib đã chạy)

#import "KAConfig.h"
#import "Headers.h"
#import <objc/runtime.h>
#import <notify.h>

static BOOL gFolder = NO;

static void KAShowLoadedToast(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Toast đơn giản qua UIAlert (1 lần mỗi respring)
        static BOOL shown = NO;
        if (shown) return;
        shown = YES;

        UIWindow *win = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { win = w; break; }
        }
        if (!win) win = [UIApplication sharedApplication].windows.firstObject;
        UIViewController *root = win.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        if (!root) return;

        UIAlertController *ac = [UIAlertController
            alertControllerWithTitle:@"KeepAlive"
            message:@"Tweak đã load vào SpringBoard.\nHold icon app → Bật KeepAlive."
            preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:ac animated:YES completion:nil];
        NSLog(@"[KeepAlive] SpringBoard loaded OK");
    });
}

#pragma mark - IMMORTAL

%group SpringBoardCore

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
    KAConfig *c = [KAConfig shared];
    if (!c.enabled) return a;
    NSString *bid = [self.icon applicationBundleID];
    if (bid && [c isImmortal:bid]) {
        SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:bid];
        a = app.processState ? 4 : 2;
    }
    if ([self.icon isKindOfClass:%c(SBFolderIcon)]) {
        for (SBIcon *ic in [(SBFolderIcon *)self.icon folder].icons) {
            NSString *b = [ic applicationBundleID];
            if (b && [c isImmortal:b] && !gFolder) {
                SBApplication *app = [[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:b];
                a = app.processState ? 4 : 2;
            }
        }
    }
    return a;
}

- (NSArray *)applicationShortcutItems {
    NSArray *orig = %orig ?: @[];
    if (![KAConfig shared].enabled) return orig;

    NSString *bid = nil;
    if ([self.icon respondsToSelector:@selector(applicationBundleID)])
        bid = [self.icon applicationBundleID];
    if (!bid.length && [self respondsToSelector:@selector(applicationBundleIdentifierForShortcuts)])
        bid = [(id)self applicationBundleIdentifierForShortcuts];
    if (!bid.length && [self respondsToSelector:@selector(applicationBundleIdentifier)])
        bid = [(id)self applicationBundleIdentifier];
    if (!bid.length) return orig;

    BOOL on = [[KAConfig shared] isImmortal:bid];
    SBSApplicationShortcutItem *item = [[%c(SBSApplicationShortcutItem) alloc] init];
    item.localizedTitle = on ? @"Tắt KeepAlive" : @"Bật KeepAlive";
    item.localizedSubtitle = @"Giữ nền + luôn popup";
    item.type = KA_SHORTCUT;
    item.bundleIdentifierToLaunch = bid;
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"bolt.horizontal.circle.fill"];
        if (img) {
            item.icon = [[%c(SBSApplicationShortcutCustomImageIcon) alloc]
                initWithImageData:UIImagePNGRepresentation(img) dataType:0 isTemplate:YES];
        }
    }
    return [orig arrayByAddingObject:item];
}

+ (void)activateShortcut:(SBSApplicationShortcutItem *)item
    withBundleIdentifier:(NSString *)bundleID
             forIconView:(id)iconView {
    if (item && [item.type isEqualToString:KA_SHORTCUT]) {
        NSString *bid = bundleID ?: item.bundleIdentifierToLaunch;
        [[KAConfig shared] toggleImmortal:bid];
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

%hook SBFolderView
- (void)willTransitionAnimated:(BOOL)a withSettings:(id)s {
    gFolder = YES;
    %orig;
}
- (void)didTransitionAnimated:(BOOL)a {
    gFolder = NO;
    %orig;
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

%hook UNSUserNotificationServer
- (void)willPresentNotification:(id)notif
            forBundleIdentifier:(NSString *)bundle
          withCompletionHandler:(id)handler {
    if ([[KAConfig shared] isImmortal:bundle]) {
        [self _didChangeApplicationState:4 forBundleIdentifier:bundle];
        void (^orig)(NSUInteger) = handler;
        void (^forced)(NSUInteger) = ^(NSUInteger options) {
            if (orig) orig(options | KA_PRESENT_ALL);
        };
        %orig(notif, bundle, forced);
        return;
    }
    %orig;
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        KAShowLoadedToast();
    });
}
%end

%end // SpringBoardCore

#pragma mark - In-app popup force

%group InAppPopup

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
    if (!delegate || ![KAConfig shared].enabled) return;
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

%end

#pragma mark - ctor

static void KAPrefs(CFNotificationCenterRef c, void *o, CFStringRef n,
                    const void *obj, CFDictionaryRef i) {
    [[KAConfig shared] reload];
}

%ctor {
    @autoreleasepool {
        [[KAConfig shared] reload];
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, KAPrefs,
            CFSTR(KA_NOTIFY_CSTR), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSLog(@"[KeepAlive] ctor in %@", bid);

        if ([bid isEqualToString:@"com.apple.springboard"]) {
            %init(SpringBoardCore);
            NSLog(@"[KeepAlive] SpringBoard hooks installed");
        } else {
            %init(InAppPopup);
        }
    }
}
