#import <Foundation/Foundation.h>

#define KA_PREFS @"com.local.keepalive.prefs"
#define KA_NOTIFY @"com.local.keepalive.prefschanged"

// List app đang immortal (giống Immortalizer)
#define KA_IMMORTAL_KEY @"KeepAliveImmortalBundleIDs"

#define KA_KEY_ENABLED @"enabled"
// Popup: MẶC ĐỊNH LUÔN BẬT, không có option tắt trong UI (bắt buộc)
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
