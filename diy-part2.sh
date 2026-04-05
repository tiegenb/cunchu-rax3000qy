#!/bin/bash
# ==================== diy-part2.sh ====================

if [ ! -d "package/base-files" ]; then
    echo "❌ ERROR: 请在 OpenWrt 源码根目录执行此脚本"
    exit 1
fi

mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults

# 1. System 配置（直接覆盖）
cat > files/etc/config/system << 'EOF'
config system
    option hostname 'WiFirepeater'
    option description '室外大功率WIFI无线中继器'
    option zonename 'Asia/Shanghai'
    option timezone 'CST-8'
    option log_proto 'udp'
    option conloglevel '8'
    option cronloglevel '5'
    option zram_comp_algo 'lzo'

config timeserver 'ntp'
    option enabled '0'
    option enable_server '0'
EOF

# 2. 默认 IP 修改
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 3. 无线配置：使用更可靠的方案
cat > files/etc/uci-defaults/99-wireless-setup << 'EOF'
#!/bin/sh
# 无线配置脚本 - 带重试机制

# 日志函数
log() {
    logger -t "wireless-setup" "$1"
}

log "开始无线配置..."

# 等待无线设备就绪（最多等待30秒）
for i in 1 2 3 4 5 6; do
    if ls /sys/class/ieee80211/ 2>/dev/null | grep -q .; then
        log "无线设备已就绪"
        break
    fi
    log "等待无线设备... ($i/6)"
    sleep 5
done

# 删除旧配置，重新生成
rm -f /etc/config/wireless
wifi config

# 再等待一下配置生成
sleep 3

# 获取所有 wifi 设备
DEVS=$(uci show wireless | grep "=wifi-device" | cut -d. -f2)

for dev in $DEVS; do
    # 获取设备对应的 phy
    phy=$(uci get wireless.$dev.phy 2>/dev/null)
    if [ -z "$phy" ]; then
        continue
    fi
    
    # 检测频率
    if iw $phy info 2>/dev/null | grep -q "2402 MHz"; then
        # 2.4G 设备
        log "配置 2.4G 设备: $dev (phy: $phy)"
        uci set wireless.$dev.htmode='HE40'
        uci set wireless.$dev.channel='auto'
        uci set wireless.$dev.txpower='18'
        uci set wireless.$dev.country='US'
        
        # 配置对应的接口
        for iface in $(uci show wireless | grep "device='$dev'" | cut -d. -f2); do
            uci set wireless.$iface.ssid='铁哥中继器-2.4G'
            uci set wireless.$iface.encryption='none'
            log "设置 2.4G SSID: 铁哥中继器-2.4G"
        done
    fi
    
    if iw $phy info 2>/dev/null | grep -q "5180 MHz"; then
        # 5G 设备
        log "配置 5G 设备: $dev (phy: $phy)"
        uci set wireless.$dev.htmode='HE80'
        uci set wireless.$dev.channel='auto'
        uci set wireless.$dev.txpower='30'
        uci set wireless.$dev.country='US'
        
        for iface in $(uci show wireless | grep "device='$dev'" | cut -d. -f2); do
            uci set wireless.$iface.ssid='铁哥中继器-5G'
            uci set wireless.$iface.encryption='none'
            log "设置 5G SSID: 铁哥中继器-5G"
        done
    fi
done

# 提交并应用
uci commit wireless
/etc/init.d/network restart
wifi up

log "无线配置完成"

exit 0
EOF

chmod +x files/etc/uci-defaults/99-wireless-setup

# 4. 兜底方案：如果上面脚本失败，还有一个 rc.local 备用
cat > files/etc/rc.local << 'EOF'
#!/bin/sh
# 兜底方案：检查无线是否配置成功，如果没有则重新配置

# 检查是否已经配置过
if [ -f /etc/.wireless_ok ]; then
    exit 0
fi

# 检查 SSID 是否正确
if ! iw dev 2>/dev/null | grep -q "铁哥中继器"; then
    logger -t "rc.local" "无线配置未生效，重新执行配置"
    # 重新执行无线配置脚本
    if [ -f /etc/uci-defaults/99-wireless-setup ]; then
        sh /etc/uci-defaults/99-wireless-setup
    fi
fi

touch /etc/.wireless_ok
exit 0
EOF

chmod +x files/etc/rc.local

echo "✅ 配置完成（含双重保障）"
