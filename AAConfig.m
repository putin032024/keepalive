#import "AAConfig.h"
#import "Headers.h"
#import <objc/runtime.h>
#import <notify.h>

@implementation AAConfig

+ (instancetype)shared {
    static AAConfig *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [AAConfig new]; [s reload]; });
    return s;
}

- (void)reload {
    NSUserDefaults *p = [[NSUserDefaults alloc] initWithSuiteName:AA_PREFS_SUITE];
    // default: bật hết
    self.enabled = [p objectForKey:AA_KEY_ENABLED] ? [p boolForKey:AA_KEY_ENABLED] : YES;
    self.forceBanner = [p objectForKey:AA_KEY_FORCE_BANNER] ? [p boolForKey:AA_KEY_FORCE_BANNER] : YES;
    self.indicator = [p objectForKey:AA_KEY_INDICATOR] ? [p boolForKey:AA_KEY_INDICATOR] : YES;
    self.lockFromKill = [p objectForKey:AA_KEY_LOCK_KILL] ? [p boolForKey:AA_KEY_LOCK_KILL] : YES;
}

- (NSMutableArray<NSString *> *)immortalIDs {
    NSArray *a = [[NSUserDefaults standardUserDefaults] arrayForKey:AA_KEY_IMMORTAL];
    return a ? [a mutableCopy] : [NSMutableArray array];
}

- (void)saveImmortalIDs:(NSArray<NSString *> *)ids {
    [[NSUserDefaults standardUserDefaults] setObject:ids forKey:AA_KEY_IMMORTAL];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)isImmortal:(NSString *)bundle {
    if (!bundle || !self.enabled) return NO;
    return [[self immortalIDs] containsObject:bundle];
}

- (void)toggleImmortal:(NSString *)bundle {
    if (!bundle.length) return;
    NSMutableArray *ids = [self immortalIDs];
    if ([ids containsObject:bundle]) {
        [ids removeObject:bundle];
    } else {
        [ids addObject:bundle];
        // mở app 1 lần để process sống
        [[objc_getClass("FBSSystemService") sharedService] openApplication:bundle options:nil withResult:nil];
    }
    [self saveImmortalIDs:ids];
    [self refreshIcon:bundle];
}

- (NSMutableArray<NSString *> *)lockedIDs {
    NSArray *a = [[NSUserDefaults standardUserDefaults] arrayForKey:AA_KEY_LOCKED];
    return a ? [a mutableCopy] : [NSMutableArray array];
}

- (void)saveLockedIDs:(NSArray<NSString *> *)ids {
    [[NSUserDefaults standardUserDefaults] setObject:ids forKey:AA_KEY_LOCKED];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)isLocked:(NSString *)bundle {
    if (!bundle || !self.lockFromKill) return NO;
    return [[self lockedIDs] containsObject:bundle];
}

- (NSString *)appName:(NSString *)bundle {
    Class ctrl = objc_getClass("SBIconController");
    if (!ctrl) return bundle;
    SBIconController *ic = [ctrl sharedInstance];
    SBIcon *icon = [ic.model applicationIconForBundleIdentifier:bundle];
    if ([icon respondsToSelector:@selector(displayName)]) {
        return [(id)icon displayName] ?: bundle;
    }
    SBApplication *app = [[objc_getClass("SBApplicationController") sharedInstance]
                          applicationWithBundleIdentifier:bundle];
    return app.displayName ?: bundle;
}

- (void)refreshIcon:(NSString *)bundle {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class ctrl = objc_getClass("SBIconController");
        if (!ctrl) return;
        SBIcon *icon = [[ctrl sharedInstance].model applicationIconForBundleIdentifier:bundle];
        [icon _notifyAccessoriesDidUpdate];
    });
}

@end
