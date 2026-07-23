// TweakScene.x — GIỮ APP SỐNG (core Immortalizer-style)
// Muốn chỉnh cách "không suspend" → sửa file này

#import "AAConfig.h"
#import "Headers.h"

// Chặn scene deactivate khi app nằm trong list immortal
%hook FBScene

- (void)updateSettings:(id)arg1 withTransitionContext:(id)arg2 completion:(id)arg3 {
    FBProcess *process = self.clientProcess;
    if (process) {
        NSString *bid = process.bundleIdentifier;
        // arg2 == nil thường là deactivate/background transition
        if ([[AAConfig shared] isImmortal:bid] && arg2 == nil) {
            [[AAConfig shared] refreshIcon:bid];
            return; // KHÔNG gọi orig → app không bị background-kill logic
        }
    }
    %orig;
}

%end

// Chặn deactivation reasons (UIKit scene)
%hook UIMutableApplicationSceneSettings

- (void)setDeactivationReasons:(unsigned long long)arg1 {
    // 0 = active. Non-zero = deactivate.
    // Không biết bundle ở đây → chặn mọi deactivation non-zero
    // (Immortalizer gốc cũng làm vậy — aggressive)
    // Nếu app khác lỗi, đổi thành chỉ chặn khi có flag.
    if (arg1 != 0) {
        // Chỉ bỏ qua nếu đang có ít nhất 1 app immortal
        if ([[AAConfig shared] enabled] && [[AAConfig shared] immortalIDs].count > 0) {
            return;
        }
    }
    %orig;
}

%end
