#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <SystemConfiguration/CaptiveNetwork.h>

@interface WiFiInfoManager : NSObject <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, copy) NSString *currentSSID;
@property (nonatomic, assign) BOOL obtained;
@end

@implementation WiFiInfoManager

+ (instancetype)sharedManager {
    static WiFiInfoManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[WiFiInfoManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
        _semaphore = dispatch_semaphore_create(0);
        _obtained = NO;
    }
    return self;
}

- (CLAuthorizationStatus)getAuthStatus {
    if (@available(iOS 14.0, *)) {
        return _locationManager.authorizationStatus;
    } else {
        return [CLLocationManager authorizationStatus];
    }
}

- (NSString *)getCurrentSSID {
    CLAuthorizationStatus status = [self getAuthStatus];
    
    if (status == kCLAuthorizationStatusNotDetermined) {
        if (@available(iOS 14.0, *)) {
            [_locationManager requestWhenInUseAuthorization];
        }
    }
    
    status = [self getAuthStatus];
    if (status < kCLAuthorizationStatusAuthorizedWhenInUse) {
        printf("Error: Location permission required\n");
        printf("Enable in Settings > Privacy > Location Services\n");
        return nil;
    }
    
    [_locationManager startUpdatingLocation];
    
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
    dispatch_semaphore_wait(_semaphore, timeout);
    
    [_locationManager stopUpdatingLocation];
    
    if (_obtained && _currentSSID) {
        return _currentSSID;
    }
    
    return [self getSSIDFromSystem];
}

- (NSString *)getSSIDFromSystem {
    NSString *ssid = nil;
    
    CFArrayRef interfacesRef = CNCopySupportedInterfaces();
    if (!interfacesRef) {
        return nil;
    }
    
    NSArray *interfaces = (__bridge_transfer NSArray *)interfacesRef;
    for (NSString *iface in interfaces) {
        CFDictionaryRef infoRef = CNCopyCurrentNetworkInfo((__bridge CFStringRef)iface);
        if (!infoRef) continue;
        
        NSDictionary *info = (__bridge_transfer NSDictionary *)infoRef;
        NSString *ssidValue = info[@"SSID"];
        if (ssidValue) {
            ssid = ssidValue;
            break;
        }
    }
    
    return ssid;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    CLLocation *location = [locations lastObject];
    if (location.horizontalAccuracy < 100) {
        _obtained = YES;
        _currentSSID = [self getSSIDFromSystem];
        dispatch_semaphore_signal(_semaphore);
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    _obtained = YES;
    dispatch_semaphore_signal(_semaphore);
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        WiFiInfoManager *manager = [WiFiInfoManager sharedManager];
        NSString *ssid = [manager getCurrentSSID];
        
        if (!ssid) {
            printf("Not connected to WiFi\n");
            printf("Note: iOS 13+ requires location permission\n");
            return 0;
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
        } else {
            printf("SSID: %s\n", [ssid UTF8String]);
        }
        
        return 0;
    }
}
