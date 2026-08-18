#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <wlanapi.h>
#pragma comment(lib, "wlanapi.lib")
#else
#include <unistd.h>
#endif

void usage(const char *prog) {
    printf("GetWiFi - 获取WiFi信息工具\n");
    printf("用法: %s [选项]\n", prog);
    printf("选项:\n");
    printf("  无参数      显示当前WiFi信息\n");
    printf("  --json      以JSON格式输出\n");
    printf("  -h, --help  显示帮助信息\n");
    printf("\n");
}

#ifdef _WIN32

int get_windows_wifi(const char *json_output) {
    HANDLE hClient;
    DWORD dwMaxClient;
    DWORD dwCurVersion;
    DWORD result;

    result = WlanOpenHandle(2, NULL, &dwMaxClient, &dwCurVersion, &hClient);
    if (result != ERROR_SUCCESS) {
        printf("错误: 无法打开WLAN客户端 (错误码: %lu)\n", result);
        return 1;
    }

    PWLAN_CONNECTION_INFO pConnInfo = NULL;
    result = WlanQueryInterface(hClient, &GUID_DEVINTERFACE_802_11,
                                WlanQueryConnectionInformation, NULL, NULL,
                                (LPVOID*)&pConnInfo);
    if (result != ERROR_SUCCESS || pConnInfo == NULL) {
        printf("当前未连接WiFi\n");
        WlanCloseHandle(hClient, NULL);
        return 0;
    }

    char ssid_str[256] = "N/A";
    char bssid_str[256] = "N/A";
    char signal_str[64] = "0";

    if (pConnInfo->isState == wlan_connected) {
        if (pConnInfo->wlanConnectionSecurity == wlan_security_wpa2 ||
            pConnInfo->wlanConnectionSecurity == wlan_security_wpa3 ||
            pConnInfo->wlanConnectionSecurity == wlan_security_wpa ||
            pConnInfo->wlanConnectionSecurity == wlan_security_wep ||
            pConnInfo->wlanConnectionSecurity == wlan_security_8021x) {
            
            if (pConnInfo->dot11Ssid.uSSIDLength > 0 && 
                pConnInfo->dot11Ssid.uSSIDLength <= 32) {
                memcpy(ssid_str, pConnInfo->dot11Ssid.ucSSID, 
                       pConnInfo->dot11Ssid.uSSIDLength);
                ssid_str[pConnInfo->dot11Ssid.uSSIDLength] = '\0';
            }
            
            if (pConnInfo->dot11Bssid) {
                sprintf(bssid_str, "%02X:%02X:%02X:%02X:%02X:%02X",
                        pConnInfo->dot11Bssid[0], pConnInfo->dot11Bssid[1],
                        pConnInfo->dot11Bssid[2], pConnInfo->dot11Bssid[3],
                        pConnInfo->dot11Bssid[4], pConnInfo->dot11Bssid[5]);
            }

            if (pConnInfo->wlanSignalQuality) {
                int signal = (int)pConnInfo->wlanSignalQuality;
                signal = -100 + (signal * 100 / 100) * 0 - (100 - signal);
                sprintf(signal_str, "%d", -100 + (pConnInfo->wlanSignalQuality * 50 / 100));
            }
        }
    }

    if (json_output) {
        printf("{\n");
        printf("  \"SSID\": \"%s\",\n", ssid_str);
        printf("  \"BSSID\": \"%s\",\n", bssid_str);
        printf("  \"signalStrength\": %s,\n", signal_str);
        printf("  \"platform\": \"windows\"\n");
        printf("}\n");
    } else {
        printf("SSID: %s\n", ssid_str);
        printf("BSSID: %s\n", bssid_str);
        printf("信号质量: %s%%\n", signal_str);
        printf("平台: Windows\n");
    }

    WlanFreeMemory(pConnInfo);
    WlanCloseHandle(hClient, NULL);
    return 0;
}

#endif

#ifdef __APPLE__

#include <CoreFoundation/CoreFoundation.h>
#include <SystemConfiguration/SystemConfiguration.h>

int get_macos_wifi(const char *json_output) {
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

            if (json_output) {
                printf("{\n");
                printf("  \"SSID\": \"%s\",\n", ssidStr);
                printf("  \"BSSID\": \"%s\",\n", bssidStr);
                printf("  \"interface\": \"%s\",\n", 
                       CFStringGetCStringPtr(ifaceName, kCFStringEncodingUTF8));
                printf("  \"platform\": \"macos\"\n");
                printf("}\n");
            } else {
                printf("SSID: %s\n", ssidStr);
                printf("BSSID: %s\n", bssidStr);
                printf("平台: macOS\n");
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
    }

    return found ? 0 : 0;
}

#endif

int main(int argc, char *argv[]) {
    int json_output = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            usage(argv[0]);
            return 0;
        }
        if (strcmp(argv[i], "--json") == 0) {
            json_output = 1;
        }
    }

#ifdef _WIN32
    return get_windows_wifi(json_output ? "1" : NULL);
#elif defined(__APPLE__)
    return get_macos_wifi(json_output ? "1" : NULL);
#else
    printf("此工具暂不支持当前平台\n");
    printf("支持: Windows, macOS, iOS (越狱)\n");
    return 1;
#endif
}
