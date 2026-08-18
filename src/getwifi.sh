#!/bin/sh

SSID=""
BSSID=""

show_help() {
    echo "GetWiFi - iOS WiFi SSID tool (shell version)"
    echo "Usage: getwifi [--json|--help]"
    echo ""
    echo "Options:"
    echo "  (no args)    Show current WiFi SSID"
    echo "  --json       Output in JSON format"
    echo "  --help       Show this help"
}

get_ssid_method1() {
    PlistBuddy="/usr/libexec/PlistBuddy"
    plist="/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist"
    if [ -x "$PlistBuddy" ] && [ -f "$plist" ]; then
        SSID=$("$PlistBuddy" -c "Print :CurrentNetwork:SSID" "$plist" 2>/dev/null)
        BSSID=$("$PlistBuddy" -c "Print :CurrentNetwork:BSSID" "$plist" 2>/dev/null)
        if [ -n "$SSID" ]; then
            return 0
        fi
    fi
    return 1
}

get_ssid_method2() {
    PlistBuddy="/usr/libexec/PlistBuddy"
    plist="/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist"
    if [ -x "$PlistBuddy" ] && [ -f "$plist" ]; then
        BSSID=$("$PlistBuddy" -c "Print :CurrentNetwork:BSSID" "$plist" 2>/dev/null)
        if [ -n "$BSSID" ]; then
            SSID="(connected)"
            return 0
        fi
    fi
    return 1
}

get_ssid_method3() {
    PlistBuddy="/usr/libexec/PlistBuddy"
    for plist in /Library/Preferences/SystemConfiguration/*.plist; do
        if [ -x "$PlistBuddy" ] && [ -f "$plist" ]; then
            result=$("$PlistBuddy" -c "Print" "$plist" 2>/dev/null | grep -i "ssid" | head -1)
            if [ -n "$result" ]; then
                SSID=$(echo "$result" | sed 's/.*= //' | tr -d '"')
                if [ -n "$SSID" ]; then
                    return 0
                fi
            fi
        fi
    done
    return 1
}

if [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

get_ssid_method1 || get_ssid_method2 || get_ssid_method3

if [ -z "$SSID" ]; then
    echo "Not connected to WiFi or cannot get SSID"
    echo "Possible reasons:"
    echo "  - No WiFi connection"
    echo "  - Rootless jailbreak sandbox restriction"
    echo ""
    echo "Try using the binary version: /var/jb/usr/local/bin/getwifi_bin"
    exit 1
fi

if [ "$1" = "--json" ]; then
    echo "{"
    echo "  \"SSID\": \"$SSID\","
    if [ -n "$BSSID" ]; then
        echo "  \"BSSID\": \"$BSSID\","
    fi
    echo "  \"timestamp\": $(date +%s)"
    echo "}"
else
    echo "SSID: $SSID"
    if [ -n "$BSSID" ]; then
        echo "BSSID: $BSSID"
    fi
fi
