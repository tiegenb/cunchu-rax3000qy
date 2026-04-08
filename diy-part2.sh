#!/bin/bash
# ==================== diy-part2.sh ====================

set -e  # 遇到错误立即退出

# ============================================
# 第一部分：系统配置
# ============================================

# 创建必要目录
mkdir -p files/etc/config

# 1. System 配置（直接覆盖，已开启 NTP 服务器）
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
    option enabled '1'
EOF

# 2. 默认 IP 修改
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
    echo "✅ IP 修改完成"
else
    echo "⚠️ 警告: config_generate 文件不存在"
fi

# ============================================
# 第二部分：验证无线配置是否修改成功
# ============================================

WIRELESS_FILE="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

print_error() { 
    echo "::error::$1"
    exit 1
}

print_success() { 
    echo "::notice::$1"
}

# 检查关键配置
grep -q "htmode=\"HE40\"" "$WIRELESS_FILE" || print_error "2.4G HE40 配置失败"
grep -q "channel=\"auto\"" "$WIRELESS_FILE" || print_error "2.4G 信道配置失败"
grep -q "铁哥中继器-2.4G" "$WIRELESS_FILE" || print_error "2.4G SSID 配置失败"
grep -q "铁哥中继器-5G" "$WIRELESS_FILE" || print_error "5G SSID 配置失败"
grep -q "mu_beamformer=1" "$WIRELESS_FILE" || print_error "MU-MIMO mu_beamformer 配置失败"
grep -q "mu_beamformee=1" "$WIRELESS_FILE" || print_error "MU-MIMO mu_beamformee 配置失败"
grep -q "he_bss_color=1" "$WIRELESS_FILE" || print_error "256-QAM he_bss_color 配置失败"
grep -q "he_su_beamformer=1" "$WIRELESS_FILE" || print_error "256-QAM he_su_beamformer 配置失败"

print_success "所有无线配置验证通过！"

echo "✅ 所有配置完成"
