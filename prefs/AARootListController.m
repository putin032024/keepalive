#import "AARootListController.h"
#import <Preferences/PSSpecifier.h>
#import <notify.h>

@implementation AARootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)respring {
    notify_post("com.local.keepalive.prefschanged");
    // Optional hard respring:
    // system("sbreload");
}

@end
