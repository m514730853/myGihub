#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <SystemConfiguration/SystemConfiguration.h>
#endif

int main(int argc, char *argv[]) {
    printf("=== GetWiFi - iOS WiFi 信息获取工具 ===\n\n");
    
#ifdef __APPLE__
    CFArrayRef interfaces = CNCopySupportedInterfaces();
    if (!interfaces) {
        printf("错误: 无法获取网络接口列表\n");
        return 1;
    }
    
    CFIndex count = CFArrayGetCount(interfaces);
    int found = 0;
    
    for (CFIndex i = 0; i < count; i++) {
        CFStringRef ifaceName = CFArrayGetValueAtIndex(interfaces, i);
        CFDictionaryRef info = CNCopyCurrentNetworkInfo(ifaceName);
        
        if (!info) continue;
        
        CFStringRef ssid = CFDictionaryGetValue(info, kCNNetworkInfoKeySSID);
        CFStringRef bssid = CFDictionaryGetValue(info, kCNNetworkInfoKeyBSSID);
        
        if (ssid) {
            char ssidStr[256];
            char bssidStr[256];
            
            CFStringGetCString(ssid, ssidStr, sizeof(ssidStr), kCFStringEncodingUTF8);
            
            if (bssid) {
                CFStringGetCString(bssid, bssidStr, sizeof(bssidStr), kCFStringEncodingUTF8);
            } else {
                strcpy(bssidStr, "N/A");
            }
            
            printf("SSID: %s\n", ssidStr);
            printf("BSSID: %s\n", bssidStr);
            
            if (argc > 1 && strcmp(argv[1], "--json") == 0) {
                printf("\n{\n");
                printf("  \"SSID\": \"%s\",\n", ssidStr);
                printf("  \"BSSID\": \"%s\",\n", bssidStr);
                printf("  \"interface\": \"%s\"\n", CFStringGetCStringPtr(ifaceName, kCFStringEncodingUTF8));
                printf("}\n");
            }
            
            found = 1;
            CFRelease(info);
            break;
        }
        
        CFRelease(info);
    }
    
    CFRelease(interfaces);
    
    if (!found) {
        printf("当前未连接WiFi\n");
        return 0;
    }
    
#else
    printf("此工具仅支持 macOS/iOS 系统\n");
    return 1;
#endif
    
    return 0;
}
