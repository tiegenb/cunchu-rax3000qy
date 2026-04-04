#!/bin/bash
# diy-part2.sh - 文件系统定制（简洁稳定版）

echo "=========================================="
echo "Starting diy-part2.sh modifications..."
echo "=========================================="

# 1. 修改默认 IP
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
echo "✓ IP changed to 192.168.66.1"

# 2. 直接修改 mac80211.sh 中的默认参数
WIFI_SCRIPT="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ -f "$WIFI_SCRIPT" ]; then
    # 国家码 US
    sed -i 's/option country '\''.*'\''/option country '\''US'\''/g' "$WIFI_SCRIPT"
    
    # 2.4G 默认 htmode
    sed -i 's/htmode="HT20"/htmode="HT40"/g' "$WIFI_SCRIPT"
    sed -i 's/htmode="HE20"/htmode="HE40"/g' "$WIFI_SCRIPT"
    
    # 5G 默认 htmode
    sed -i 's/htmode="VHT80"/htmode="VHT80"/g' "$WIFI_SCRIPT"  # 已经是 80
    sed -i 's/htmode="HE80"/htmode="HE80"/g' "$WIFI_SCRIPT"    # 已经是 80
    
    # SSID
    sed -i 's/ssid="OpenWrt"/ssid="铁哥中继器"/g' "$WIFI_SCRIPT"
    
    echo "✓ Wireless defaults configured"
else
    echo "⚠ Warning: mac80211.sh not found"
fi

# 3. 创建 rc.local
mkdir -p files/etc
cat > files/etc/rc.local << 'EOF'
#!/bin/sh
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo ondemand > $cpu 2>/dev/null
done
exit 0
EOF
chmod +x files/etc/rc.local

echo "=========================================="
echo "diy-part2.sh completed!"
echo "=========================================="
