#import <Foundation/Foundation.h>
#import <MobileWiFi/WiFiManager.h>
#import <MobileWiFi/WiFiNetwork.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        WiFiManager *manager = [WiFiManager sharedManager];
        
        if (!manager) {
            printf("Error: 无法初始化WiFi管理器\n");
            return 1;
        }
        
        WiFiNetwork *currentNetwork = [manager currentNetwork];
        
        if (!currentNetwork) {
            printf("当前未连接WiFi\n");
            return 0;
        }
        
        NSString *ssid = [currentNetwork SSID];
        NSString *bssid = [currentNetwork BSSID];
        int signalStrength = [currentNetwork signalStrength];
        NSString *securityType = [currentNetwork securityType];
        
        printf("SSID: %s\n", [ssid UTF8String]);
        printf("BSSID: %s\n", [bssid UTF8String]);
        printf("信号强度: %d dBm\n", signalStrength);
        printf("安全类型: %s\n", [securityType UTF8String]);
        
        if (argc > 1 && strcmp(argv[1], "--json") == 0) {
            NSDictionary *info = @{
                @"SSID": ssid ?: @"",
                @"BSSID": bssid ?: @"",
                @"signalStrength": @(signalStrength),
                @"securityType": securityType ?: @"",
                @"connected": @YES
            };
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info 
                                                             options:NSJSONWritingPrettyPrinted 
                                                               error:&error];
            if (jsonData) {
                NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                printf("\nJSON:\n%s\n", [jsonStr UTF8String]);
            }
        }
        
        return 0;
    }
}
