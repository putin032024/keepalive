#import <UIKit/UIKit.h>

// Minimal PSListController decls (link Preferences on device)
@interface PSSpecifier : NSObject
@end

@interface PSListController : UIViewController
- (NSArray *)specifiers;
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (void)setSpecifiers:(NSArray *)specifiers;
@end

@interface AARootListController : PSListController
@end
