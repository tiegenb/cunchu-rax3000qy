#!/bin/bash
# ==================== diy-part2.sh ====================

# 验证是否在 OpenWrt 源码目录
if [ ! -d "package/base-files" ]; then
    echo "❌ ERROR: 请在 OpenWrt 源码根目录执行此脚本"
    exit 1
fi

# 创建 files 目录
mkdir -p files/etc/uci-defaults

# 1. 写入 system 配置（直接覆盖文件）
mkdir -p files/etc/config
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

# 2. 无线配置使用脚本动态生成（不写死 wireless 文件）
cat > files/etc/uci-defaults/99-wireless-setup << 'EOF'
#!/bin/sh
# 首次开机时自动配置无线

# 删除可能存在的旧配置
rm -f /etc/config/wireless

# 让驱动自动检测硬件并生成配置
wifi config

# 等待配置文件生成
sleep 2

# 获取实际的物理网卡（phy0, phy1...）
PHYS=$(ls /sys/class/ieee80211/ 2>/dev/null)

# 用于记录哪个是 2.4G，哪个是 5G
PHY_24G=""
PHY_5G=""

# 识别 2.4G 和 5G
for phy in $PHYS; do
    # 检查该 phy 支持的频率
    if iw $phy info | grep -q "2402.*2472"; then
        PHY_24G=$phy
    fi
    if iw $phy info | grep -q "5180.*5885"; then
        PHY_5G=$phy
    fi
done

# 获取对应的 radio 编号
if [ -n "$PHY_24G" ]; then
    RADIO_24G=$(uci show wireless | grep "phy='$PHY_24G'" | head -1 | cut -d. -f2)
    if [ -n "$RADIO_24G" ]; then
        uci set wireless.$RADIO_24G.htmode='HE40'
        uci set wireless.$RADIO_24G.channel='auto'
        uci set wireless.$RADIO_24G.cell_density='0'
        uci set wireless.$RADIO_24G.mu_beamformer='1'
        uci set wireless.$RADIO_24G.txpower='18'
        uci set wireless.$RADIO_24G.country='US'
        
        # 修改对应的 SSID
        for iface in $(uci show wireless | grep "device='$RADIO_24G'" | cut -d. -f2); do
            uci set wireless.$iface.ssid='铁哥中继器-2.4G'
            uci set wireless.$iface.encryption='none'
        done
    fi
fi

if [ -n "$PHY_5G" ]; then
    RADIO_5G=$(uci show wireless | grep "phy='$PHY_5G'" | head -1 | cut -d. -f2)
    if [ -n "$RADIO_5G" ]; then
        uci set wireless.$RADIO_5G.htmode='HE80'
        uci set wireless.$RADIO_5G.channel='auto'
        uci set wireless.$RADIO_5G.cell_density='0'
        uci set wireless.$RADIO_5G.mu_beamformer='1'
        uci set wireless.$RADIO_5G.txpower='30'
        uci set wireless.$RADIO_5G.country='US'
        
        # 修改对应的 SSID
        for iface in $(uci show wireless | grep "device='$RADIO_5G'" | cut -d. -f2); do
            uci set wireless.$iface.ssid='铁哥中继器-5G'
            uci set wireless.$iface.encryption='none'
        done
    fi
fi

# 提交配置
uci commit wireless

# 重启无线
/etc/init.d/network restart
wifi up

# 删除自己（首次执行后自动删除）
exit 0
EOF

# 3. 修改默认 IP
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 4. 设置脚本权限
chmod +x files/etc/uci-defaults/99-wireless-setup

echo "✅ 配置完成"
