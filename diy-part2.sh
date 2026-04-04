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
    
    # 2.4G 带宽 40MHz
    sed -i 's/htmode="HT20"/htmode="HT40"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="HE20"/htmode="HE40"/g' "$WIFI_SCRIPT"
    
    # SSID
    sed -i 's/ssid="OpenWrt"/ssid="铁哥中继器"/g' "$WIFI_SCRIPT"
    
    echo "   ✓ Country: US"
    echo "   ✓ 2.4G: 40MHz"
    echo "   ✓ SSID: 铁哥中继器"
else
    echo "   ⚠ Warning: $WIFI_SCRIPT not found"
fi

# 3. 创建 rc.local（CPU 调度器设置）
echo "3. Creating rc.local..."
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
echo "   ✓ Created rc.local"

echo "=========================================="
echo "diy-part2.sh completed!"
echo "=========================================="
