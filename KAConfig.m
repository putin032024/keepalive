#import "KAConfig.h"
#import "Headers.h"
#import <objc/runtime.h>

@implementation KAConfig

+ (instancetype)shared {
    static KAConfig *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [KAConfig new];
        [s reload];
    });
    return s;
}

- (NSUserDefaults *)sharedDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName:KA_SHARED];
}

- (void)reload {
    NSUserDefaults *p = [[NSUserDefaults alloc] initWithSuiteName:KA_PREFS];
    self.enabled = [p objectForKey:KA_KEY_ENABLED] ? [p boolForKey:KA_KEY_ENABLED] : YES;
}

- (NSMutableArray<NSString *> *)immortalIDs {
    NSArray *a = [[self sharedDefaults] arrayForKey:KA_IMMORTAL_KEY];
    // migrate old key from standardUserDefaults if any
    if (!a.count) {
        a = [[NSUserDefaults standardUserDefaults] arrayForKey:@"KeepAliveImmortalBundleIDs"];
    }
    return a ? [a mutableCopy] : [NSMutableArray array];
}

- (void)saveImmortalIDs:(NSArray<NSString *> *)ids {
    NSUserDefaults *d = [self sharedDefaults];
    [d setObject:ids forKey:KA_IMMORTAL_KEY];
    [d synchronize];
    // cũng ghi standard (SpringBoard) để tương thích
    [[NSUserDefaults standardUserDefaults] setObject:ids forKey:@"KeepAliveImmortalBundleIDs"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // Darwin notify apps reload
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(KA_NOTIFY_CSTR), NULL, NULL, true);
}

- (BOOL)isImmortal:(NSString *)bundle {
    if (!bundle.length || !self.enabled) return NO;
    return [[self immortalIDs] containsObject:bundle];
}

- (void)toggleImmortal:(NSString *)bundle {
    if (!bundle.length) return;
    NSMutableArray *ids = [self immortalIDs];
    if ([ids containsObject:bundle]) {
        [ids removeObject:bundle];
        NSLog(@"[KeepAlive] OFF %@", bundle);
    } else {
        [ids addObject:bundle];
        NSLog(@"[KeepAlive] ON %@", bundle);
        // Mở app 1 lần rồi user về Home — process sống + audio nền
        [[objc_getClass("FBSSystemService") sharedService]
            openApplication:bundle options:nil withResult:nil];
    }
    [self saveImmortalIDs:ids];
    [self refreshIcon:bundle];
}

- (void)refreshIcon:(NSString *)bundle {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class c = objc_getClass("SBIconController");
        if (!c) return;
        SBIconController *ic = (SBIconController *)[c sharedInstance];
        SBIcon *icon = [ic.model applicationIconForBundleIdentifier:bundle];
        [icon _notifyAccessoriesDidUpdate];
    });
}

@end
