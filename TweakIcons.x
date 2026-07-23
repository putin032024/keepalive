// TweakIcons.x — 3D Touch / long-press menu bật-tắt Immortal + indicator + chặn vuốt kill

#import "AAConfig.h"
#import "Headers.h"
#import <objc/runtime.h>

static BOOL gFolderTransition = NO;

%group SpringBoardIcons

%hook SBIconView

- (long long)currentLabelAccessoryType {
    long long acc = %orig;
    AAConfig *cfg = [AAConfig shared];
    if (!cfg.enabled || !cfg.indicator) return acc;

    NSString *bid = [self.icon applicationBundleID];
    if (bid && [cfg isImmortal:bid]) {
        SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                              applicationWithBundleIdentifier:bid];
        // 4 = hourglass-ish / 2 = dot (tùy iOS)
        acc = app.processState ? 4 : 2;
    }

    if ([self.icon isKindOfClass:%c(SBFolderIcon)]) {
        SBFolder *folder = [(SBFolderIcon *)self.icon folder];
        for (SBIcon *ic in folder.icons) {
            NSString *fb = [ic applicationBundleID];
            if (fb && [cfg isImmortal:fb] && !gFolderTransition) {
                SBApplication *app = [[%c(SBApplicationController) sharedInstance]
                                      applicationWithBundleIdentifier:fb];
                acc = app.processState ? 4 : 2;
            }
        }
    }
    return acc;
}

- (NSArray *)applicationShortcutItems {
    NSArray *orig = %orig;
    AAConfig *cfg = [AAConfig shared];
    if (!cfg.enabled) return orig;

    NSString *bid = [self.icon applicationBundleID];
    if (!bid.length) return orig;

    BOOL on = [cfg isImmortal:bid];
    SBSApplicationShortcutItem *item = [[%c(SBSApplicationShortcutItem) alloc] init];
    item.localizedTitle = on ? @"Tắt AlwaysAlive" : @"Bật AlwaysAlive";
    item.localizedSubtitle = on ? @"Thôi giữ nền" : @"Giữ nền + ép banner";
    item.type = AA_SHORTCUT_TYPE;
    UIImage *img = [UIImage systemImageNamed:@"bolt.horizontal.circle.fill"];
    if (img) {
        item.icon = [[%c(SBSApplicationShortcutCustomImageIcon) alloc]
                     initWithImageData:UIImagePNGRepresentation(img) dataType:0 isTemplate:YES];
    }
    item.bundleIdentifierToLaunch = bid;
    return [orig arrayByAddingObject:item];
}

+ (void)activateShortcut:(SBSApplicationShortcutItem *)item
    withBundleIdentifier:(NSString *)bundleID
            forIconView:(id)iconView {
    if ([item.type isEqualToString:AA_SHORTCUT_TYPE]) {
        [[AAConfig shared] toggleImmortal:bundleID];
        return;
    }
    %orig;
}

%end

%hook SBApplication

- (long long)labelAccessoryTypeForIcon:(id)arg1 {
    long long acc = %orig;
    AAConfig *cfg = [AAConfig shared];
    if (cfg.enabled && cfg.indicator && [cfg isImmortal:self.bundleIdentifier]) {
        acc = self.processState ? 4 : 2;
    }
    return acc;
}

- (void)_didExitWithContext:(id)arg1 {
    %orig;
    [[AAConfig shared] refreshIcon:self.bundleIdentifier];
}

%end

%hook SBFolderView

- (void)willTransitionAnimated:(BOOL)arg1 withSettings:(id)arg2 {
    gFolderTransition = YES;
    %orig;
}

- (void)didTransitionAnimated:(BOOL)arg1 {
    gFolderTransition = NO;
    %orig;
}

%end

// Chặn vuốt kill app đã lock (list riêng — mặc định = immortal list nếu muốn gộp)
%hook SBFluidSwitcherItemContainer

- (void)setKillable:(BOOL)arg1 {
    BOOL killable = arg1;
    AAConfig *cfg = [AAConfig shared];
    if (cfg.enabled && cfg.lockFromKill) {
        SBAppLayout *layout = [self appLayout];
        NSDictionary *map = nil;
        if (@available(iOS 16.0, *)) {
            map = [layout itemsToLayoutAttributesMap];
        } else {
            Ivar iv = class_getInstanceVariable(object_getClass(layout), "_rolesToLayoutItemsMap");
            if (iv) map = object_getIvar(layout, iv);
        }
        if (map) {
            if (@available(iOS 16.0, *)) {
                for (SBDisplayItem *item in map) {
                    if ([cfg isImmortal:item.bundleIdentifier] || [cfg isLocked:item.bundleIdentifier]) {
                        killable = NO;
                    }
                }
            } else {
                SBDisplayItem *item = map[@1];
                NSString *bid = [item respondsToSelector:@selector(bundleIdentifier)] ? item.bundleIdentifier : nil;
                if (bid && ([cfg isImmortal:bid] || [cfg isLocked:bid])) killable = NO;
            }
        }
    }
    %orig(killable);
}

%end

%end

%ctor {
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if ([bid isEqualToString:@"com.apple.springboard"]) {
        %init(SpringBoardIcons);
    }
}
