#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <SystemConfiguration/CaptiveNetwork.h>

typedef struct __WiFiManager WiFiManager;
typedef struct __WiFiDevice WiFiDevice;

typedef WiFiManager* (*WiFiManagerShared_fn)(void);
typedef WiFiDevice*  (*WiFiDeviceGetDevice_fn)(void);
typedef CFStringRef  (*WiFiDeviceGetSSID_fn)(WiFiDevice *);
typedef CFStringRef  (*WiFiDeviceGetBSSID_fn)(WiFiDevice *);
typedef int          (*WiFiDeviceGetRSSI_fn)(WiFiDevice *);

static void *g_wifiLib = NULL;

static BOOL initWiFiLib(void) {
    if (g_wifiLib) return YES;
    g_wifiLib = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_LAZY);
    if (!g_wifiLib) {
        g_wifiLib = dlopen("/System/Library/Frameworks/MobileWiFi.framework/MobileWiFi", RTLD_LAZY);
    }
    return g_wifiLib != NULL;
}

static NSString *getSSIDViaPrivateAPI(void) {
    if (!initWiFiLib()) return nil;

    WiFiManagerShared_fn WiFiManagerShared = (WiFiManagerShared_fn)dlsym(g_wifiLib, "WiFiManagerShared");
    WiFiDeviceGetDevice_fn WiFiDeviceGetDevice = (WiFiDeviceGetDevice_fn)dlsym(g_wifiLib, "WiFiDeviceGetDevice");
    WiFiDeviceGetSSID_fn WiFiDeviceGetSSID = (WiFiDeviceGetSSID_fn)dlsym(g_wifiLib, "WiFiDeviceGetSSID");

    if (!WiFiManagerShared || !WiFiDeviceGetDevice || !WiFiDeviceGetSSID) return nil;

    WiFiManager *manager = WiFiManagerShared();
    if (!manager) return nil;

    WiFiDevice *device = WiFiDeviceGetDevice();
    if (!device) return nil;

    CFStringRef ssidRef = WiFiDeviceGetSSID(device);
    if (!ssidRef) return nil;

    NSString *ssid = (__bridge_transfer NSString *)CFStringCreateCopy(NULL, ssidRef);
    return ssid;
}

static NSString *getSSIDViaPublicAPI(void) {
    NSString *ssid = nil;
    CFArrayRef interfacesRef = CNCopySupportedInterfaces();
    if (!interfacesRef) return nil;

    NSArray *interfaces = (__bridge_transfer NSArray *)interfacesRef;
    for (NSString *iface in interfaces) {
        CFDictionaryRef infoRef = CNCopyCurrentNetworkInfo((__bridge CFStringRef)iface);
        if (!infoRef) continue;
        NSDictionary *info = (__bridge_transfer NSDictionary *)infoRef;
        NSString *ssidValue = info[@"SSID"];
        if (ssidValue && ssidValue.length > 0) {
            ssid = ssidValue;
            break;
        }
    }
    return ssid;
}

static NSString *getSSID(void) {
    NSString *ssid = getSSIDViaPrivateAPI();
    if (ssid) return ssid;
    return getSSIDViaPublicAPI();
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *ssid = getSSID();

        if (!ssid) {
            printf("No WiFi connected or cannot get SSID\n");
            printf("Try: /var/jb/usr/local/bin/getwifi --help\n");
            return 1;
        }

        if (argc > 1 && strcmp(argv[1], "--json") == 0) {
            NSDictionary *info = @{
                @"SSID": ssid,
                @"timestamp": @([[NSDate date] timeIntervalSince1970])
            };
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info
                                                             options:NSJSONWritingPrettyPrinted
                                                               error:&error];
            if (jsonData) {
                NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                printf("%s\n", [jsonStr UTF8String]);
            }
        } else if (argc > 1 && strcmp(argv[1], "--help") == 0) {
            printf("GetWiFi - iOS WiFi SSID tool\n");
            printf("Usage: getwifi [--json|--help]\n\n");
            printf("Options:\n");
            printf("  (no args)    Show current WiFi SSID\n");
            printf("  --json       Output in JSON format\n");
            printf("  --help       Show this help\n\n");
            printf("Examples:\n");
            printf("  getwifi\n");
            printf("  getwifi --json\n");
        } else {
            printf("SSID: %s\n", [ssid UTF8String]);
        }

        return 0;
    }
}
