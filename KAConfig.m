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

- (void)reload {
    NSUserDefaults *p = [[NSUserDefaults alloc] initWithSuiteName:KA_PREFS];
    self.enabled = [p objectForKey:KA_KEY_ENABLED] ? [p boolForKey:KA_KEY_ENABLED] : YES;
}

- (NSMutableArray<NSString *> *)immortalIDs {
    NSArray *a = [[NSUserDefaults standardUserDefaults] arrayForKey:KA_IMMORTAL_KEY];
    return a ? [a mutableCopy] : [NSMutableArray array];
}

- (void)saveImmortalIDs:(NSArray<NSString *> *)ids {
    [[NSUserDefaults standardUserDefaults] setObject:ids forKey:KA_IMMORTAL_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    } else {
        [ids addObject:bundle];
        [[objc_getClass("FBSSystemService") sharedService] openApplication:bundle options:nil withResult:nil];
    }
    [self saveImmortalIDs:ids];
    [self refreshIcon:bundle];
}

- (void)refreshIcon:(NSString *)bundle {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class c = objc_getClass("SBIconController");
        if (!c) return;
        SBIcon *icon = [[c sharedInstance].model applicationIconForBundleIdentifier:bundle];
        [icon _notifyAccessoriesDidUpdate];
    });
}

@end
