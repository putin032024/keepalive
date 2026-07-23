// Tweak.x — entry / prefs observer (SpringBoard)
// Logic chính nằm ở:
//   TweakScene.x          → giữ app sống
//   TweakNotifications.x  → ép popup banner
//   TweakIcons.x          → menu + indicator + chống kill

#import "AAConfig.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>

static void AAReloadPrefs(CFNotificationCenterRef center, void *observer,
                          CFStringRef name, const void *object,
                          CFDictionaryRef userInfo) {
    [[AAConfig shared] reload];
}

%ctor {
    // Load prefs sớm
    [[AAConfig shared] reload];

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        AAReloadPrefs,
        CFSTR("com.local.keepalive.prefschanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );

    // SpringBoard boot xong reload lần nữa
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if ([bid isEqualToString:@"com.apple.springboard"]) {
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *n) {
            [[AAConfig shared] reload];
        }];
    }
}
