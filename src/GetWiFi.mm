#import <UIKit/UIKit.h>
#import <MobileWiFi/WiFiManager.h>
#import <MobileWiFi/WiFiNetwork.h>
#import <substrate.h>

static WiFiManager *_wifiManager = nil;

@interface GetWiFiPlugin : NSObject
@end

@implementation GetWiFiPlugin

+ (void)load {
    @autoreleasepool {
        _wifiManager = [WiFiManager sharedManager];
        
        if (_wifiManager) {
            [[NSNotificationCenter defaultCenter] addObserver:self 
                                                   selector:@selector(wifiChanged:) 
                                                       name:UIApplicationWillEnterForegroundNotification 
                                                     object:nil];
            
            NSLog(@"[GetWiFi] 插件已加载");
            NSLog(@"[GetWiFi] 当前WiFi: %@", [[_wifiManager currentNetwork] SSID]);
        }
    }
}

+ (void)wifiChanged:(NSNotification *)notification {
    WiFiNetwork *network = [_wifiManager currentNetwork];
    if (network) {
        NSLog(@"[GetWiFi] WiFi变更: %@ (信号: %d dBm)", 
              [network SSID], [network signalStrength]);
    } else {
        NSLog(@"[GetWiFi] WiFi已断开");
    }
}

+ (NSString *)currentSSID {
    WiFiNetwork *network = [_wifiManager currentNetwork];
    return [network SSID];
}

+ (NSDictionary *)currentNetworkInfo {
    WiFiNetwork *network = [_wifiManager currentNetwork];
    if (!network) {
        return @{@"connected": @NO};
    }
    
    return @{
        @"connected": @YES,
        @"SSID": [network SSID] ?: @"",
        @"BSSID": [network BSSID] ?: @"",
        @"signalStrength": @([network signalStrength]),
        @"securityType": [network securityType] ?: @""
    };
}

@end

__attribute__((constructor))
static void getwifi_init(void) {
    [GetWiFiPlugin load];
}
