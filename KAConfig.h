#import <Foundation/Foundation.h>

#define KA_PREFS @"com.local.keepalive.prefs"
// Suite dùng chung SpringBoard + app (đọc được list immortal)
#define KA_SHARED @"com.local.keepalive.shared"
#define KA_NOTIFY_CSTR "com.local.keepalive.prefschanged"
#define KA_NOTIFY @KA_NOTIFY_CSTR
#define KA_IMMORTAL_KEY @"immortalBundles"
#define KA_KEY_ENABLED @"enabled"
#define KA_SHORTCUT @"com.local.keepalive.toggle"
// Banner|List|Sound|Badge|Alert
#define KA_PRESENT_ALL (1u | 2u | 4u | 8u | 16u)

@interface KAConfig : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL enabled;
- (void)reload;
- (NSMutableArray<NSString *> *)immortalIDs;
- (void)saveImmortalIDs:(NSArray<NSString *> *)ids;
- (BOOL)isImmortal:(NSString *)bundle;
- (void)toggleImmortal:(NSString *)bundle;
- (void)refreshIcon:(NSString *)bundle;
@end
