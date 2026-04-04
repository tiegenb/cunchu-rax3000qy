#!/bin/bash
# diy-part2.sh - 文件系统定制

echo "=========================================="
echo "Starting diy-part2.sh modifications..."
echo "=========================================="

# 1. 修改默认 IP
echo "1. Modifying default IP to 192.168.66.1..."
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
echo "   ✓ IP changed"

# 2. 修改无线默认配置
echo "2. Modifying wireless defaults..."
WIFI_SCRIPT="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ -f "$WIFI_SCRIPT" ]; then
    # 国家码 US
    sed -i 's/country="CN"/country="US"/g' "$WIFI_SCRIPT"
    sed -i "s/option country 'CN'/option country 'US'/g" "$WIFI_SCRIPT"
    echo "   ✓ Country: US"
    
    # 2.4G 带宽 40MHz
    sed -i 's/htmode="HT20"/htmode="HT40"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="HE20"/htmode="HE40"/g' "$WIFI_SCRIPT"
    echo "   ✓ 2.4G bandwidth: 40MHz"
    
    # 5G 带宽 80MHz
    sed -i 's/htmode="VHT20"/htmode="VHT80"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="VHT40"/htmode="VHT80"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="HE20"/htmode="HE80"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="HE40"/htmode="HE80"/g' "$WIFI_SCRIPT"
    echo "   ✓ 5G bandwidth: 80MHz"
    
    # 基础 SSID
    sed -i 's/ssid="OpenWrt"/ssid="铁哥中继器"/g' "$WIFI_SCRIPT"
    echo "   ✓ Base SSID: 铁哥中继器"
else
    echo "   ⚠ Warning: $WIFI_SCRIPT not found"
fi

# 3. 创建 uci-defaults 脚本（设置功率和 SSID 后缀）
echo "3. Creating uci-defaults for power and SSID settings..."
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-wifi-config << 'EOF'
#!/bin/sh
# 分别设置 2.4G 和 5G 的 SSID 和发射功率

for radio in $(uci show wireless | grep "=wifi-device" | cut -d. -f2 | cut -d= -f1); do
    hwmode=$(uci get wireless.$radio.hwmode 2>/dev/null)
    
    case "$hwmode" in
        *11a*|*11ax*|*11ac*)
            uci set wireless.$radio.txpower=27 2>/dev/null
            for iface in $(uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1); do
                device=$(uci get wireless.$iface.device 2>/dev/null)
                [ "$device" = "$radio" ] && uci set wireless.$iface.ssid="铁哥中继器-5G" 2>/dev/null
            done
            ;;
        *11g*|*11b*|*11n*)
            uci set wireless.$radio.txpower=16 2>/dev/null
            for iface in $(uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1); do
                device=$(uci get wireless.$iface.device 2>/dev/null)
                [ "$device" = "$radio" ] && uci set wireless.$iface.ssid="铁哥中继器-2.4G" 2>/dev/null
            done
            ;;
    esac
done

uci commit wireless
exit 0
EOF

chmod +x files/etc/uci-defaults/99-wifi-config
echo "   ✓ Created uci-defaults"

# 4. 创建 rc.local
echo "4. Creating rc.local..."
mkdir -p files/etc
cat > files/etc/rc.local << 'EOF'
#!/bin/sh
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$cpu" ] && echo ondemand > $cpu 2>/dev/null
done
exit 0
EOF
chmod +x files/etc/rc.local
echo "   ✓ Created rc.local"

# 5. 清理可能冲突的预设配置
echo "5. Cleaning up potential conflicting configs..."
rm -f files/etc/config/wireless 2>/dev/null
echo "   ✓ Cleanup done"

echo "=========================================="
echo "diy-part2.sh completed!"
echo ""
echo "配置摘要："
echo "  IP: 192.168.66.1"
echo "  国家: US"
echo "  2.4G: 40MHz, 16dBm, 铁哥中继器-2.4G"
echo "  5G: 80MHz, 27dBm, 铁哥中继器-5G"
echo "=========================================="
