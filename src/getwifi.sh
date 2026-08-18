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
    for prefix in "" "/var/jb"; do
        plist="${prefix}/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist"
        if [ -f "$plist" ]; then
            SSID=$(sudo "$PlistBuddy" -c "Print :CurrentNetwork:SSID" "$plist" 2>/dev/null)
            BSSID=$(sudo "$PlistBuddy" -c "Print :CurrentNetwork:BSSID" "$plist" 2>/dev/null)
            if [ -n "$SSID" ] && [ "$SSID" != "" ] && [ "$SSID" != "The path/key does not exist" ]; then
                return 0
            fi
        fi
    done
    return 1
}

get_ssid_method2() {
    PlistBuddy="/usr/libexec/PlistBuddy"
    for prefix in "" "/var/jb"; do
        plist="${prefix}/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist"
        if [ -f "$plist" ]; then
            BSSID=$(sudo "$PlistBuddy" -c "Print :CurrentNetwork:BSSID" "$plist" 2>/dev/null)
            if [ -n "$BSSID" ] && [ "$BSSID" != "The path/key does not exist" ]; then
                SSID="(connected)"
                return 0
            fi
        fi
    done
    return 1
}

get_ssid_method3() {
    PlistBuddy="/usr/libexec/PlistBuddy"
    for prefix in "" "/var/jb"; do
        sysdir="${prefix}/Library/Preferences/SystemConfiguration"
        if [ -d "$sysdir" ]; then
            for plist in "$sysdir"/*.plist; do
                if [ -f "$plist" ]; then
                    result=$(sudo "$PlistBuddy" -c "Print" "$plist" 2>/dev/null | grep -i "ssid" | head -1)
                    if [ -n "$result" ]; then
                        SSID=$(echo "$result" | sed 's/.*= //' | tr -d '"')
                        if [ -n "$SSID" ] && [ "$SSID" != "" ]; then
                            return 0
                        fi
                    fi
                fi
            done
        fi
    done
    return 1
}

debug_info() {
    echo "=== Debug Info ==="
    echo "Date: $(date)"
    echo "Kernel: $(uname -a)"
    echo ""
    echo "Checking paths..."
    for p in \
        "/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist" \
        "/var/jb/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist" \
        "/usr/libexec/PlistBuddy"; do
        if [ -f "$p" ]; then
            echo "  [EXISTS] $p"
        else
            echo "  [MISSING] $p"
        fi
    done
    echo ""
    echo "Trying PlistBuddy directly..."
    PlistBuddy="/usr/libexec/PlistBuddy"
    for plist in \
        "/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist" \
        "/var/jb/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist"; do
        if [ -f "$plist" ]; then
            echo "  File: $plist"
            sudo "$PlistBuddy" -c "Print" "$plist" 2>/dev/null | head -20
            echo ""
        fi
    done
    echo "=== End Debug ==="
}

if [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ "$1" = "--debug" ]; then
    debug_info
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
