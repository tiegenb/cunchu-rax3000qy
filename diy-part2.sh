#!/bin/bash
# diy-part2.sh - 文件系统定制

echo "=========================================="
echo "Starting diy-part2.sh modifications..."
echo "=========================================="

# 设置默认无线功率（创建默认配置文件）
echo "1. Setting default WiFi txpower..."

# 创建默认配置目录
mkdir -p files/etc/config

# 生成无线配置文件（如果不存在则创建）
if [ ! -f files/etc/config/wireless ]; then
    cat > files/etc/config/wireless << 'EOF'
# 自动生成的无线配置 - 功率优化版
config wifi-device 'radio0'
        option type 'mac80211'
        option hwmode '11ax'
        option path 'platform/soc/c000000.wifi'
        option channel 'auto'
        option htmode 'HE20'
        option country 'CN'
        option txpower '18'
        option disabled '0'

config wifi-iface 'default_radio0'
        option device 'radio0'
        option network 'lan'
        option mode 'ap'
        option ssid 'ImmortalWrt'
        option encryption 'none'

config wifi-device 'radio1'
        option type 'mac80211'
        option hwmode '11ax'
        option path 'platform/soc/c000000.wifi+1'
        option channel 'auto'
        option htmode 'HE80'
        option country 'CN'
        option txpower '20'
        option disabled '0'

config wifi-iface 'default_radio1'
        option device 'radio1'
        option network 'lan'
        option mode 'ap'
        option ssid 'ImmortalWrt-5G'
        option encryption 'none'
EOF
    echo "   ✓ Created wireless config with 2.4G:18dBm, 5G:20dBm"
else
    echo "   ⚠ Wireless config already exists, skipping..."
fi

# 创建开机自动优化脚本（可选）
echo "2. Creating rc.local optimization script..."

cat > files/etc/rc.local << 'EOF'
#!/bin/sh
# 开机自动优化 - 确保功率设置生效
sleep 10

# 确保CPU在ondemand模式
echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
echo ondemand > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor 2>/dev/null

exit 0
EOF

chmod +x files/etc/rc.local
echo "   ✓ Created rc.local script"

echo "=========================================="
echo "diy-part2.sh completed successfully!"
echo "=========================================="
# Modify default IP
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
