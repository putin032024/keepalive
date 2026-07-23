#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

@interface SBApplicationProcessState : NSObject
@end

@interface SBApplication : NSObject
@property (nonatomic, readonly) SBApplicationProcessState *processState;
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, copy, readonly) NSString *displayName;
@end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundle;
@end

@interface SBIcon : NSObject
- (NSString *)applicationBundleID;
- (void)_notifyAccessoriesDidUpdate;
@end

@interface SBFolder : NSObject
@property (nonatomic, copy, readonly) NSArray *icons;
@end

@interface SBFolderIcon : SBIcon
@property (nonatomic, readonly) SBFolder *folder;
@end

@interface SBIconModel : NSObject
- (SBIcon *)applicationIconForBundleIdentifier:(NSString *)bundle;
@end

@interface SBIconController : NSObject
@property (nonatomic, retain) SBIconModel *model;
+ (instancetype)sharedInstance;
@end

@interface SBIconView : UIView
@property (nonatomic, copy) NSString *location;
@property (nonatomic, retain) SBIcon *icon;
@end

@interface SBSApplicationShortcutIcon : NSObject
@end

@interface SBSApplicationShortcutCustomImageIcon : SBSApplicationShortcutIcon
- (id)initWithImageData:(NSData *)data dataType:(long long)type isTemplate:(BOOL)isTemplate;
@end

@interface SBSApplicationShortcutItem : NSObject
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *localizedTitle;
@property (nonatomic, copy) NSString *localizedSubtitle;
@property (nonatomic, copy) NSString *bundleIdentifierToLaunch;
@property (nonatomic, copy) SBSApplicationShortcutIcon *icon;
@end

@interface FBProcess : NSObject
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface FBScene : NSObject
@property (nonatomic, readonly) FBProcess *clientProcess;
@end

@interface FBSSystemService : NSObject
+ (id)sharedService;
- (void)openApplication:(NSString *)bundle options:(id)opts withResult:(id)result;
@end

@interface UNSUserNotificationServer : NSObject
+ (id)sharedInstance;
- (void)_didChangeApplicationState:(unsigned)state forBundleIdentifier:(NSString *)bundle;
@end

@interface SBAppLayout : NSObject
@property (nonatomic, readonly) NSDictionary *itemsToLayoutAttributesMap;
@end

@interface SBDisplayItem : NSObject
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface SBFluidSwitcherItemContainer : NSObject
@property (nonatomic, retain) SBAppLayout *appLayout;
- (void)setKillable:(BOOL)killable;
@end

@interface SBFolderView : UIView
@property (nonatomic, retain) SBFolder *folder;
- (void)willTransitionAnimated:(BOOL)arg1 withSettings:(id)arg2;
- (void)didTransitionAnimated:(BOOL)arg1;
@end

@interface UIMutableApplicationSceneSettings : NSObject
- (void)setDeactivationReasons:(unsigned long long)reasons;
@end
