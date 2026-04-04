#!/bin/bash
# diy-part2.sh - 文件系统定制

echo "=========================================="
echo "Starting diy-part2.sh modifications..."
echo "=========================================="

# ============================================
# 1. 修改默认 IP 为 192.168.66.1
# ============================================
echo "1. Modifying default IP to 192.168.66.1..."
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
echo "   ✓ IP changed to 192.168.66.1"

# ============================================
# 2. 修改无线默认配置（国家、带宽、功率、SSID）
# ============================================
echo "2. Modifying wireless defaults..."
WIFI_SCRIPT="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ -f "$WIFI_SCRIPT" ]; then
    # 2.1 国家代码 US
    sed -i 's/country="CN"/country="US"/g' "$WIFI_SCRIPT"
    sed -i "s/option country 'CN'/option country 'US'/g" "$WIFI_SCRIPT"
    echo "   ✓ Country: US"
    
    # 2.2 2.4G 带宽 40MHz
    sed -i 's/htmode="HT20"/htmode="HT40"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="HE20"/htmode="HE40"/g' "$WIFI_SCRIPT"
    echo "   ✓ 2.4G bandwidth: 40MHz"
    
    # 2.3 5G 带宽 80MHz
    sed -i 's/htmode="VHT20"/htmode="VHT80"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="VHT40"/htmode="VHT80"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="HE20"/htmode="HE80"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="HE40"/htmode="HE80"/g' "$WIFI_SCRIPT"
    echo "   ✓ 5G bandwidth: 80MHz"
    
    # 2.4 基础 SSID
    sed -i 's/ssid="OpenWrt"/ssid="铁哥中继器"/g' "$WIFI_SCRIPT"
    
    # 2.5 删除原有的自动添加 -5G 后缀的逻辑
    sed -i '/\[ "$hwmode" = "11a" \] && ssid="${ssid}-5G"/d' "$WIFI_SCRIPT"
    echo "   ✓ Base SSID: 铁哥中继器"
else
    echo "   ⚠ Warning: $WIFI_SCRIPT not found"
fi

# ============================================
# 3. 创建 uci-defaults 脚本（设置功率和 SSID 后缀）
# ============================================
echo "3. Creating uci-defaults for power and SSID settings..."
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-wifi-config << 'EOF'
#!/bin/sh
# 分别设置 2.4G 和 5G 的 SSID 和发射功率

# 获取所有无线设备
for radio in $(uci show wireless | grep "=wifi-device" | cut -d. -f2 | cut -d= -f1); do
    # 获取频段信息
    hwmode=$(uci get wireless.$radio.hwmode 2>/dev/null)
    
    case "$hwmode" in
        *11a*|*11ax*|*11ac*)
            # 5G 频段
            uci set wireless.$radio.txpower=27 2>/dev/null
            # 找到对应的 iface 并设置 SSID
            for iface in $(uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1); do
                device=$(uci get wireless.$iface.device 2>/dev/null)
                if [ "$device" = "$radio" ]; then
                    uci set wireless.$iface.ssid="铁哥中继器-5G" 2>/dev/null
                fi
            done
            ;;
        *11g*|*11b*|*11n*)
            # 2.4G 频段
            uci set wireless.$radio.txpower=16 2>/dev/null
            # 找到对应的 iface 并设置 SSID
            for iface in $(uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1); do
                device=$(uci get wireless.$iface.device 2>/dev/null)
                if [ "$device" = "$radio" ]; then
                    uci set wireless.$iface.ssid="铁哥中继器-2.4G" 2>/dev/null
                fi
            done
            ;;
    esac
done

uci commit wireless
exit 0
EOF

chmod +x files/etc/uci-defaults/99-wifi-config
echo "   ✓ Created uci-defaults for power (2.4G:16dBm, 5G:27dBm) and SSID suffixes"

# ============================================
# 4. 创建 rc.local（CPU 调度器设置）
# ============================================
echo "4. Creating rc.local for CPU governor..."
mkdir -p files/etc

cat > files/etc/rc.local << 'EOF'
#!/bin/sh
# 设置 CPU 调度器为 ondemand
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$cpu" ] && echo ondemand > $cpu 2>/dev/null
done
exit 0
EOF

chmod +x files/etc/rc.local
echo "   ✓ Created rc.local (CPU governor: ondemand)"

# ============================================
# 5. 清理可能冲突的预设配置
# ============================================
echo "5. Cleaning up potential conflicting configs..."
rm -f files/etc/config/wireless 2>/dev/null
echo "   ✓ Removed any preset wireless config"

echo "=========================================="
echo "diy-part2.sh completed successfully!"
echo ""
echo "=========================================="
echo "最终配置摘要："
echo "=========================================="
echo "✅ 管理 IP: 192.168.66.1"
echo "✅ 国家代码: US"
echo "✅ 2.4G: 40MHz, 功率 16dBm, SSID: 铁哥中继器-2.4G"
echo "✅ 5G: 80MHz, 功率 27dBm, SSID: 铁哥中继器-5G"
echo "✅ CPU 调度器: ondemand (开机自动设置)"
echo "=========================================="
echo ""
echo "📌 注意："
echo "   - 首次启动约 1-2 分钟后配置自动生效"
echo "   - 之后可在 Luci 界面中修改"
echo "=========================================="
