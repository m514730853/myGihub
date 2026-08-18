#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <MobileWiFi/WiFiManager.h>
#import <MobileWiFi/WiFiNetwork.h>

@interface WiFiStatusItem : NSObject
@property (nonatomic, strong) UIWindow *statusWindow;
@property (nonatomic, strong) UILabel *ssidLabel;
@property (nonatomic, strong) NSTimer *updateTimer;
@end

@implementation WiFiStatusItem

+ (void)load {
    @autoreleasepool {
        WiFiStatusItem *item = [[WiFiStatusItem alloc] init];
        [item setupStatusBarItem];
        [item startUpdating];
        NSLog(@"[WiFiStatus] 插件已启动");
    }
}

- (void)setupStatusBarItem {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    _statusWindow = [[UIWindow alloc] initWithFrame:CGRectMake(screenBounds.size.width - 150, 0, 150, 20)];
    _statusWindow.windowLevel = UIWindowLevelStatusBar + 1;
    _statusWindow.backgroundColor = [UIColor clearColor];
    [_statusWindow makeKeyAndVisible];
    
    _ssidLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 130, 20)];
    _ssidLabel.font = [UIFont systemFontOfSize:11];
    _ssidLabel.textColor = [UIColor whiteColor];
    _ssidLabel.textAlignment = NSTextAlignmentRight;
    _ssidLabel.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self 
                                                                         action:@selector(showWiFiInfo)];
    [_ssidLabel addGestureRecognizer:tap];
    
    [_statusWindow addSubview:_ssidLabel];
    
    [self updateDisplay];
}

- (void)startUpdating {
    _updateTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 
                                                   target:self 
                                                 selector:@selector(updateDisplay) 
                                                 userInfo:nil 
                                                  repeats:YES];
}

- (void)updateDisplay {
    WiFiManager *manager = [WiFiManager sharedManager];
    WiFiNetwork *network = [manager currentNetwork];
    
    if (network) {
        NSString *ssid = [network SSID];
        int signal = [network signalStrength];
        NSString *signalIcon = [self signalIconForStrength:signal];
        _ssidLabel.text = [NSString stringWithFormat:@"%@ %@", signalIcon, ssid];
    } else {
        _ssidLabel.text = @"📡 未连接";
    }
}

- (NSString *)signalIconForStrength:(int)strength {
    if (strength > -50) return @"📶";
    if (strength > -65) return @"📶";
    if (strength > -75) return @"📶";
    return @"📡";
}

- (void)showWiFiInfo {
    WiFiManager *manager = [WiFiManager sharedManager];
    WiFiNetwork *network = [manager currentNetwork];
    
    NSString *message;
    if (network) {
        message = [NSString stringWithFormat:
                   @"SSID: %@\nBSSID: %@\n信号强度: %d dBm\n安全类型: %@",
                   [network SSID],
                   [network BSSID],
                   [network signalStrength],
                   [network securityType]];
    } else {
        message = @"当前未连接WiFi";
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"WiFi 信息" 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                     style:UIAlertActionStyleDefault 
                                                   handler:nil];
    [alert addAction:okAction];
    
    UIViewController *topVC = [self topViewController];
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (UIViewController *)topViewController {
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    return rootVC;
}

@end

__attribute__((constructor))
static void wifi_status_init(void) {
    [WiFiStatusItem load];
}
