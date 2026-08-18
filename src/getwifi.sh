#!/bin/sh

SSID=""
BSSID=""

show_help() {
    echo "GetWiFi - iOS WiFi SSID tool (shell version)"
    echo "Usage: getwifi [--json|--help|--debug]"
    echo ""
    echo "Options:"
    echo "  (no args)    Show current WiFi SSID"
    echo "  --json       Output in JSON format"
    echo "  --help       Show this help"
    echo "  --debug      Show debug information"
}

debug_info() {
    echo "=== Debug Info ==="
    echo "Date: $(date)"
    echo "Kernel: $(uname -a)"
    echo ""
    echo "Searching for WiFi-related files..."
    for path in \
        "/Library/Preferences/SystemConfiguration" \
        "/var/jb/Library/Preferences/SystemConfiguration" \
        "/usr/libexec" \
        "/var/jb/usr/libexec" \
        "/usr/sbin" \
        "/var/jb/usr/sbin"; do
        if [ -d "$path" ]; then
            echo "  [EXISTS] $path"
            ls "$path" 2>/dev/null | grep -iE "wifi|plistbuddy|network" | head -5
        else
            echo "  [MISSING] $path"
        fi
    done
    echo ""
    echo "Checking networksetup..."
    for ns in /usr/sbin/networksetup /var/jb/usr/sbin/networksetup; do
        if [ -x "$ns" ]; then
            echo "  Found: $ns"
            "$ns" -listallhardwareports 2>/dev/null
            echo ""
            "$ns" -getairportnetwork en0 2>/dev/null
        else
            echo "  Missing: $ns"
        fi
    done
    echo ""
    echo "Checking ifconfig..."
    for ifc in /sbin/ifconfig /var/jb/sbin/ifconfig /usr/sbin/ifconfig; do
        if [ -x "$ifc" ]; then
            echo "  Found: $ifc"
            "$ifc" 2>/dev/null | grep -E "^[a-z]|ether" | head -10
            break
        fi
    done
    echo ""
    echo "Searching for wifi plists..."
    find /Library /var/jb/Library /tmp -name "*wifi*" -o -name "*airport*" 2>/dev/null | head -10
    echo ""
    echo "=== End Debug ==="
}

get_ssid_networksetup() {
    for ns in /usr/sbin/networksetup /var/jb/usr/sbin/networksetup; do
        if [ -x "$ns" ]; then
            for iface in en0 en1 awdl0; do
                result=$("$ns" -getairportnetwork "$iface" 2>/dev/null)
                if [ -n "$result" ] && echo "$result" | grep -q "Current Network"; then
                    SSID=$(echo "$result" | sed 's/Current Network: //')
                    return 0
                fi
            done
        fi
    done
    return 1
}

get_ssid_ifconfig() {
    for ifc in /sbin/ifconfig /var/jb/sbin/ifconfig /usr/sbin/ifconfig; do
        if [ -x "$ifc" ]; then
            for iface in en0 en1; do
                result=$("$ifc" "$iface" 2>/dev/null)
                if [ -n "$result" ]; then
                    SSID=$(echo "$result" | grep -i "ssid" | sed 's/.*ssid //' | tr -d ' ' | head -1)
                    BSSID=$(echo "$result" | grep -i "ether" | awk '{print $2}')
                    if [ -n "$SSID" ]; then
                        return 0
                    fi
                    if [ -n "$BSSID" ]; then
                        SSID="(connected, BSSID: $BSSID)"
                        return 0
                    fi
                fi
            done
        fi
    done
    return 1
}

get_ssid_plistbuddy() {
    for pb in /usr/libexec/PlistBuddy /var/jb/usr/libexec/PlistBuddy; do
        if [ -x "$pb" ]; then
            for prefix in "" "/var/jb"; do
                for plist in \
                    "${prefix}/Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist" \
                    "${prefix}/Library/Preferences/SystemConfiguration/preferences.plist"; do
                    if [ -f "$plist" ]; then
                        SSID=$(sudo "$pb" -c "Print :CurrentNetwork:SSID" "$plist" 2>/dev/null)
                        BSSID=$(sudo "$pb" -c "Print :CurrentNetwork:BSSID" "$plist" 2>/dev/null)
                        if [ -n "$SSID" ] && [ "$SSID" != "The path/key does not exist" ]; then
                            return 0
                        fi
                        if [ -n "$BSSID" ] && [ "$BSSID" != "The path/key does not exist" ]; then
                            SSID="(connected)"
                            return 0
                        fi
                    fi
                done
            done
        fi
    done
    return 1
}

get_ssid_find() {
    for searchdir in /Library /var/jb/Library /var/jb/private/var; do
        if [ -d "$searchdir" ]; then
            plist=$(find "$searchdir" -name "*wifi*" -name "*.plist" 2>/dev/null | head -1)
            if [ -n "$plist" ] && [ -f "$plist" ]; then
                for pb in /usr/libexec/PlistBuddy /var/jb/usr/libexec/PlistBuddy; do
                    if [ -x "$pb" ]; then
                        SSID=$(sudo "$pb" -c "Print :CurrentNetwork:SSID" "$plist" 2>/dev/null)
                        if [ -n "$SSID" ] && [ "$SSID" != "The path/key does not exist" ]; then
                            return 0
                        fi
                    fi
                done
            fi
        fi
    done
    return 1
}

get_ssid_system_profiler() {
    for sp in /usr/sbin/system_profiler /var/jb/usr/sbin/system_profiler; do
        if [ -x "$sp" ]; then
            result=$("$sp" SPAirPortDataType 2>/dev/null)
            if [ -n "$result" ]; then
                SSID=$(echo "$result" | grep -i "Current Network" | sed 's/.*: //' | head -1)
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

if [ "$1" = "--debug" ]; then
    debug_info
    exit 0
fi

get_ssid_networksetup || get_ssid_ifconfig || get_ssid_plistbuddy || get_ssid_find || get_ssid_system_profiler

if [ -z "$SSID" ]; then
    echo "Not connected to WiFi or cannot get SSID"
    echo ""
    echo "Debug: run 'getwifi --debug' for more info"
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
