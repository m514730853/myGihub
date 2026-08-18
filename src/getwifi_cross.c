#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <wlanapi.h>
#pragma comment(lib, "wlanapi.lib")
#pragma comment(lib, "ws2_32.lib")
#else
#include <unistd.h>
#endif

void usage(const char *prog) {
    printf("GetWiFi - WiFi info tool\n");
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  (none)    Show current WiFi info\n");
    printf("  --json    Output in JSON format\n");
    printf("  -h        Show help\n");
}

#ifdef _WIN32

int get_windows_wifi(int json_output) {
    HANDLE hClient = NULL;
    DWORD dwMaxClient = 0;
    DWORD dwCurVersion = 0;
    DWORD dwResult = 0;

    dwResult = WlanOpenHandle(2, NULL, &dwMaxClient, &dwCurVersion, &hClient);
    if (dwResult != ERROR_SUCCESS) {
        printf("Error: WlanOpenHandle failed (code: %lu)\n", dwResult);
        return 1;
    }

    PWLAN_INTERFACE_INFO_LIST pIfList = NULL;
    dwResult = WlanEnumInterfaces(hClient, NULL, &pIfList);
    if (dwResult != ERROR_SUCCESS) {
        printf("Error: WlanEnumInterfaces failed (code: %lu)\n", dwResult);
        WlanCloseHandle(hClient, NULL);
        return 1;
    }

    char ssid_str[256] = "N/A";
    char bssid_str[256] = "N/A";
    int signal_quality = 0;
    int found = 0;

    for (DWORD i = 0; i < pIfList->dwNumberOfItems; i++) {
        if (pIfList->InterfaceInfo[i].isState != wlan_interface_state_connected) {
            continue;
        }

        ULONG dwSize = 0;
        PWLAN_CONNECTION_ATTRIBUTES pAttr = NULL;
        dwResult = WlanQueryInterface(
            hClient,
            &pIfList->InterfaceInfo[i].InterfaceGuid,
            wlan_intf_opcode_current_connection,
            NULL,
            &dwSize,
            (PVOID*)&pAttr,
            NULL
        );

        if (dwResult == ERROR_SUCCESS && pAttr) {
            if (pAttr->wlanAssociationAttributes.dot11Ssid.uSSIDLength > 0 &&
                pAttr->wlanAssociationAttributes.dot11Ssid.uSSIDLength <= 32) {
                memcpy(ssid_str, pAttr->wlanAssociationAttributes.dot11Ssid.ucSSID,
                       pAttr->wlanAssociationAttributes.dot11Ssid.uSSIDLength);
                ssid_str[pAttr->wlanAssociationAttributes.dot11Ssid.uSSIDLength] = '\0';
            }

            UCHAR *bssid = pAttr->wlanAssociationAttributes.dot11Bssid;
            sprintf(bssid_str, "%02X:%02X:%02X:%02X:%02X:%02X",
                    bssid[0], bssid[1], bssid[2], bssid[3], bssid[4], bssid[5]);

            signal_quality = pAttr->wlanAssociationAttributes.wlanSignalQuality;
            found = 1;
            WlanFreeMemory(pAttr);
            break;
        }
    }

    if (pIfList) WlanFreeMemory(pIfList);
    WlanCloseHandle(hClient, NULL);

    if (!found) {
        printf("Not connected to WiFi\n");
        return 0;
    }

    if (json_output) {
        printf("{\n");
        printf("  \"SSID\": \"%s\",\n", ssid_str);
        printf("  \"BSSID\": \"%s\",\n", bssid_str);
        printf("  \"signalQuality\": %d,\n", signal_quality);
        printf("  \"platform\": \"windows\"\n");
        printf("}\n");
    } else {
        printf("SSID: %s\n", ssid_str);
        printf("BSSID: %s\n", bssid_str);
        printf("Signal: %d%%\n", signal_quality);
        printf("Platform: Windows\n");
    }

    return 0;
}

#endif

#ifdef __APPLE__

#include <CoreFoundation/CoreFoundation.h>
#include <SystemConfiguration/SystemConfiguration.h>

int get_macos_wifi(int json_output) {
    CFArrayRef interfaces = CNCopySupportedInterfaces();
    if (!interfaces) {
        printf("Error: cannot get network interfaces\n");
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
            char ssidStr[256] = "N/A";
            char bssidStr[256] = "N/A";

            CFStringGetCString(ssid, ssidStr, sizeof(ssidStr), kCFStringEncodingUTF8);
            if (bssid) {
                CFStringGetCString(bssid, bssidStr, sizeof(bssidStr), kCFStringEncodingUTF8);
            }

            if (json_output) {
                printf("{\n");
                printf("  \"SSID\": \"%s\",\n", ssidStr);
                printf("  \"BSSID\": \"%s\",\n", bssidStr);
                printf("  \"platform\": \"macos\"\n");
                printf("}\n");
            } else {
                printf("SSID: %s\n", ssidStr);
                printf("BSSID: %s\n", bssidStr);
                printf("Platform: macOS\n");
            }

            found = 1;
            CFRelease(info);
            break;
        }
        CFRelease(info);
    }

    CFRelease(interfaces);

    if (!found) {
        printf("Not connected to WiFi\n");
    }

    return 0;
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
    return get_windows_wifi(json_output);
#elif defined(__APPLE__)
    return get_macos_wifi(json_output);
#else
    printf("This tool supports Windows, macOS, and iOS\n");
    return 1;
#endif
}
