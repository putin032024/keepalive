// AAConfig — prefs + immortal app list
// Sửa key/prefs suite ở đây nếu muốn đổi package id

#import <Foundation/Foundation.h>

// Prefs suite (Settings)
#define AA_PREFS_SUITE @"com.local.keepalive.prefs"

// Darwin notify khi prefs đổi
#define AA_NOTIFY_PREFS @"com.local.keepalive.prefschanged"

// UserDefaults key: danh sách bundle đang immortal (SpringBoard NSUserDefaults)
#define AA_KEY_IMMORTAL @"AlwaysAliveImmortalBundleIDs"

// Prefs keys
#define AA_KEY_ENABLED @"enabled"
#define AA_KEY_FORCE_BANNER @"forceBanner"
#define AA_KEY_INDICATOR @"indicator"
#define AA_KEY_LOCK_KILL @"lockFromKill"
#define AA_KEY_LOCKED @"AlwaysAliveLockedBundleIDs"

// Shortcut type
#define AA_SHORTCUT_TYPE @"com.local.keepalive.toggle"

// UNNotificationPresentationOptions (iOS 14+)
// Badge=1 Sound=2 Alert=4 List=8 Banner=16
#define AA_PRESENT_ALL (1 | 2 | 4 | 8 | 16)

@interface AAConfig : NSObject
+ (instancetype)shared;

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL forceBanner;   // BẮT BUỘC hiện popup
@property (nonatomic, assign) BOOL indicator;
@property (nonatomic, assign) BOOL lockFromKill;

- (void)reload;
- (NSMutableArray<NSString *> *)immortalIDs;
- (void)saveImmortalIDs:(NSArray<NSString *> *)ids;
- (BOOL)isImmortal:(NSString *)bundle;
- (void)toggleImmortal:(NSString *)bundle;
- (NSMutableArray<NSString *> *)lockedIDs;
- (void)saveLockedIDs:(NSArray<NSString *> *)ids;
- (BOOL)isLocked:(NSString *)bundle;
- (NSString *)appName:(NSString *)bundle;
- (void)refreshIcon:(NSString *)bundle;
@end
