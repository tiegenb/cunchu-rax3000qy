#!/bin/bash
# diy-part2.sh - 文件系统定制

echo "=========================================="
echo "Starting diy-part2.sh modifications..."
echo "=========================================="

# 1. 修改默认 IP
echo "1. Modifying default IP to 192.168.66.1..."
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
echo "   ✓ IP changed"

# ==================== 添加自定义 uci-defaults 开机配置 ====================
# 创建 uci-defaults 脚本目录
mkdir -p files/etc/uci-defaults

# 写入自定义配置脚本
cat > files/etc/uci-defaults/99-custom-settings << 'EOF'
#!/bin/sh
# 功能：首次开机和恢复出厂设置时自动配置

# 检查是否已经配置过（标记文件存在则跳过）
if [ -f /etc/config/.custom_configured ]; then
    exit 0
fi

# 检查配置目录是否非空（已有配置文件则跳过）
if ls /etc/config/* 2>/dev/null | grep -qv '.custom_configured$'; then
    exit 0
fi

# --- System 配置 ---
uci set system.cfg01e48a.hostname='WiFirepeater'
uci set system.cfg01e48a.description='室外大功率WIFI无线中继器'
uci set system.cfg01e48a.zonename='Asia/Shanghai'
uci set system.cfg01e48a.timezone='CST-8'
uci set system.cfg01e48a.log_proto='udp'
uci set system.cfg01e48a.conloglevel='8'
uci set system.cfg01e48a.cronloglevel='5'
uci set system.cfg01e48a.zram_comp_algo='lzo'

# --- Wireless 配置 ---
uci set wireless.radio0.htmode='HE40'
uci set wireless.radio0.channel='auto'
uci set wireless.radio0.cell_density='0'
uci set wireless.radio0.mu_beamformer='1'
uci set wireless.radio0.txpower='18'
uci set wireless.radio0.country='US'
uci set wireless.default_radio0.ssid='铁哥中继器-2.4G'

uci set wireless.radio1.htmode='HE80'
uci set wireless.radio1.channel='auto'
uci set wireless.radio1.cell_density='0'
uci set wireless.radio1.mu_beamformer='1'
uci set wireless.radio1.txpower='30'
uci set wireless.radio1.country='US'
uci set wireless.default_radio1.ssid='铁哥中继器-5G'

# 提交配置
uci commit
/etc/init.d/network restart

# 创建标记文件
touch /etc/config/.custom_configured

exit 0
EOF

# 赋予可执行权限
chmod +x files/etc/uci-defaults/99-custom-settings

echo "✅ 已添加 uci-defaults 自定义配置脚本"
# =========================================================================
