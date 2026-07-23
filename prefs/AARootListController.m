#import "AARootListController.h"

@implementation AARootListController {
    NSArray *_specifiers;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

@end
