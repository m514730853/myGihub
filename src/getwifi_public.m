#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <SystemConfiguration/SystemConfiguration.h>

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

- (NSString *)getCurrentSSID {
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        [_locationManager requestWhenInUseAuthorization];
    }
    
    if ([CLLocationManager authorizationStatus] < kCLAuthorizationStatusAuthorizedWhenInUse) {
        printf("错误: 需要位置服务权限来获取WiFi信息\n");
        printf("请在 设置 > 隐私 > 位置服务 中允许本应用使用位置服务\n");
        return nil;
    }
    
    [_locationManager startUpdatingLocation];
    
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC);
    dispatch_semaphore_wait(_semaphore, timeout);
    
    [_locationManager stopUpdatingLocation];
    
    if (_obtained && _currentSSID) {
        return _currentSSID;
    }
    
    return [self getSSIDFromSystem];
}

- (NSString *)getSSIDFromSystem {
    NSString *ssid = nil;
    
    NSArray *interfaces = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    for (NSString *iface in interfaces) {
        NSDictionary *info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)iface);
        if (info && info[(id)kCNNetworkInfoKeySSID]) {
            ssid = info[(id)kCNNetworkInfoKeySSID];
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
            printf("当前未连接WiFi或无法获取信息\n");
            printf("提示: iOS 13+ 需要位置服务权限才能获取SSID\n");
            return 0;
        }
        
        printf("当前WiFi SSID: %s\n", [ssid UTF8String]);
        
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
                printf("\nJSON:\n%s\n", [jsonStr UTF8String]);
            }
        }
        
        return 0;
    }
}
