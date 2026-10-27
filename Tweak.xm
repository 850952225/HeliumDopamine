#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <sys/socket.h>

// HeliumDopamine: independent rootless prototype for iOS 17 / Dopamine.
// Preferences are read from /var/mobile/Library/Preferences/com.example.heliumdopamine.plist.
static UIWindow *gHUDWindow;
static UILabel *gHUDLabel;
static NSTimer *gHUDTimer;
static BOOL gEnabled = YES, gHideAfterScreenshot = YES, gShowCPU = YES, gShowMemory = YES, gShowNetwork = YES, gShowBattery = YES;
static CGFloat gOpacity = 0.78, gScale = 1.0, gX = 10.0, gY = 90.0;
static BOOL gHiddenForScreenshot = NO;
static uint64_t gLastRX = 0, gLastTX = 0;
static NSTimeInterval gLastNetTime = 0;
static double gRXRate = 0, gTXRate = 0;
static NSString *const kPrefsDomain = @"com.example.heliumdopamine";

static id Pref(NSString *key, id fallback) {
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kPrefsDomain);
    if (!value) return fallback;
    return CFBridgingRelease(value);
}
static void LoadPrefs(void) {
    gEnabled = [Pref(@"Enabled", @YES) boolValue];
    gHideAfterScreenshot = [Pref(@"HideAfterScreenshot", @YES) boolValue];
    gShowCPU = [Pref(@"ShowCPU", @YES) boolValue];
    gShowMemory = [Pref(@"ShowMemory", @YES) boolValue];
    gShowNetwork = [Pref(@"ShowNetwork", @YES) boolValue];
    gShowBattery = [Pref(@"ShowBattery", @YES) boolValue];
    gOpacity = MIN(1.0, MAX(0.15, [Pref(@"Opacity", @0.78) doubleValue]));
    gScale = MIN(1.8, MAX(0.65, [Pref(@"Scale", @1.0) doubleValue]));
    gX = [Pref(@"X", @10.0) doubleValue]; gY = [Pref(@"Y", @90.0) doubleValue];
}
static uint64_t NetworkBytes(BOOL transmit) {
    struct ifaddrs *addresses = NULL; uint64_t total = 0;
    if (getifaddrs(&addresses) != 0 || !addresses) return 0;
    for (struct ifaddrs *it = addresses; it; it = it->ifa_next) {
        if (!it->ifa_addr || it->ifa_addr->sa_family != AF_LINK || (it->ifa_flags & IFF_LOOPBACK)) continue;
        struct if_data *data = (struct if_data *)it->ifa_data;
        if (data) total += transmit ? data->ifi_obytes : data->ifi_ibytes;
    }
    freeifaddrs(addresses); return total;
}
static void UpdateNetwork(void) {
    NSTimeInterval now = [NSProcessInfo processInfo].systemUptime;
    uint64_t rx = NetworkBytes(NO), tx = NetworkBytes(YES);
    if (gLastNetTime > 0 && now > gLastNetTime) {
        double dt = now - gLastNetTime;
        gRXRate = rx >= gLastRX ? (double)(rx - gLastRX) / dt : 0;
        gTXRate = tx >= gLastTX ? (double)(tx - gLastTX) / dt : 0;
    }
    gLastRX = rx; gLastTX = tx; gLastNetTime = now;
}
static NSString *RateString(double bytes) {
    if (bytes >= 1024.0 * 1024.0) return [NSString stringWithFormat:@"%.1f MB/s", bytes / 1024.0 / 1024.0];
    return [NSString stringWithFormat:@"%.0f KB/s", bytes / 1024.0];
}
static double ProcessCPU(void) {
    thread_act_array_t threads = NULL; mach_msg_type_number_t count = 0; double cpu = 0;
    if (task_threads(mach_task_self(), &threads, &count) == KERN_SUCCESS) {
        for (mach_msg_type_number_t i = 0; i < count; i++) {
            thread_basic_info_data_t info; mach_msg_type_number_t n = THREAD_BASIC_INFO_COUNT;
            if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)&info, &n) == KERN_SUCCESS && !(info.flags & TH_FLAGS_IDLE)) cpu += (double)info.cpu_usage / TH_USAGE_SCALE * 100.0;
            mach_port_deallocate(mach_task_self(), threads[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)threads, count * sizeof(thread_act_t));
    }
    return cpu;
}
static NSString *MemoryString(void) {
    mach_port_t host = mach_host_self(); vm_size_t pageSize = 0; host_page_size(host, &pageSize);
    vm_statistics64_data_t vm; mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &count) != KERN_SUCCESS) return @"MEM --";
    double used = (double)(vm.active_count + vm.inactive_count + vm.wire_count + vm.compressor_page_count) * pageSize / 1024.0 / 1024.0;
    return [NSString stringWithFormat:@"MEM %.0f MB", used];
}
static NSString *HUDStats(void) {
    NSMutableArray *parts = [NSMutableArray arrayWithObject:@"HELIUM"];
    if (gShowCPU) [parts addObject:[NSString stringWithFormat:@"CPU %.0f%%", ProcessCPU()]];
    if (gShowMemory) [parts addObject:MemoryString()];
    if (gShowNetwork) { [parts addObject:[NSString stringWithFormat:@"↓ %@", RateString(gRXRate)]]; [parts addObject:[NSString stringWithFormat:@"↑ %@", RateString(gTXRate)]]; }
    if (gShowBattery) { UIDevice.currentDevice.batteryMonitoringEnabled = YES; float level = UIDevice.currentDevice.batteryLevel; if (level >= 0) [parts addObject:[NSString stringWithFormat:@"BAT %.0f%%", level * 100.0]]; }
    return [parts componentsJoinedByString:@"  •  "];
}
static void HUDUpdate(void) {
    if (!gHUDLabel || !gHUDWindow || !gEnabled || gHiddenForScreenshot) return;
    UpdateNetwork(); gHUDLabel.text = HUDStats();
    CGSize size = [gHUDLabel sizeThatFits:CGSizeMake(UIScreen.mainScreen.bounds.size.width - 20, 100)];
    CGFloat width = MIN(MAX(size.width + 22, 210), UIScreen.mainScreen.bounds.size.width - 20);
    gHUDWindow.frame = CGRectMake(gX, gY, width * gScale, 34 * gScale);
    gHUDLabel.frame = gHUDWindow.bounds;
    gHUDLabel.font = [UIFont monospacedSystemFontOfSize:10 * gScale weight:UIFontWeightSemibold];
    gHUDLabel.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:gOpacity];
}
static void HUDCreate(void) {
    LoadPrefs(); if (gHUDWindow || !gEnabled) return;
    CGRect bounds = UIScreen.mainScreen.bounds;
    gHUDWindow = [[UIWindow alloc] initWithFrame:CGRectMake(gX, gY, MIN(bounds.size.width - 20, 340), 34)];
    gHUDWindow.windowLevel = UIWindowLevelAlert + 100; gHUDWindow.backgroundColor = UIColor.clearColor;
    gHUDWindow.userInteractionEnabled = NO; gHUDWindow.hidden = NO;
    UIViewController *vc = [UIViewController new]; vc.view.backgroundColor = UIColor.clearColor; gHUDWindow.rootViewController = vc;
    gHUDLabel = [[UILabel alloc] initWithFrame:gHUDWindow.bounds]; gHUDLabel.numberOfLines = 1;
    gHUDLabel.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightSemibold]; gHUDLabel.textColor = UIColor.whiteColor;
    gHUDLabel.textAlignment = NSTextAlignmentCenter; gHUDLabel.layer.cornerRadius = 9; gHUDLabel.layer.masksToBounds = YES;
    [vc.view addSubview:gHUDLabel]; HUDUpdate();
    gHUDTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(__unused NSTimer *timer) { LoadPrefs(); if (!gEnabled) { gHUDWindow.hidden = YES; return; } gHUDWindow.hidden = NO; HUDUpdate(); }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *n) {
        // This notification arrives AFTER capture; this only hides HUD after the screenshot.
        if (gHideAfterScreenshot) { gHiddenForScreenshot = YES; gHUDWindow.hidden = YES; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ gHiddenForScreenshot = NO; gHUDWindow.hidden = !gEnabled; HUDUpdate(); }); }
    }];
}
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application { %orig; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ HUDCreate(); }); }
%end
