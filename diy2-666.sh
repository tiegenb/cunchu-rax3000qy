#!/bin/bash
# 文件名: diy2.sh

set -e

echo "开始执行 DIY 脚本..."
echo "========================================="

# ==================== 0. 创建必要目录 ====================
mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults

# ==================== 1. System 配置 ====================
cat > files/etc/config/system << 'EOF'
config system
    option hostname 'WiFirepeater'
    option zonename 'Asia/Shanghai'
    option timezone 'CST-8'
    option log_proto 'udp'
    option conloglevel '8'
    option cronloglevel '5'
    option zram_comp_algo 'lzo'

config timeserver 'ntp'
    option enabled '1'
    option enable_server '0'
EOF
echo "✅ System 配置完成（主机名: WiFirepeater，NTP客户端已启用）"

# ==================== 2. 默认 IP 修改 ====================
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
    echo "✅ 管理 IP: 192.168.66.1"
fi

# ==================== 3. 无线配置修改 ====================
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ ! -f "$MAC80211_SH" ]; then
    echo "错误: 找不到 $MAC80211_SH"
    exit 1
fi

cp "$MAC80211_SH" "$MAC80211_SH.bak"

# ---------- SSID 修改 ----------
sed -i '/uci -q batch <<-EOF/i\
		if [ "${mode_band}" = "2g" ]; then\
			ssid="铁哥中继器-2.4G"\
		else\
			ssid="铁哥中继器-5G"\
		fi\
' "$MAC80211_SH"

sed -i 's/set wireless.default_radio${devidx}.ssid=ImmortalWrt/set wireless.default_radio${devidx}.ssid=${ssid}/g' "$MAC80211_SH"

# ---------- 2.4G 信道自动 ----------
sed -i '/uci -q batch <<-EOF/i\
		if [ "${mode_band}" = "2g" ]; then\
			channel="auto"\
		fi\
' "$MAC80211_SH"

# ---------- 强制40MHz（noscan=1）----------
sed -i '/set wireless.radio${devidx}.htmode=/a\
			set wireless.radio${devidx}.noscan=1\
			set wireless.radio${devidx}.htmode="HT40"' "$MAC80211_SH"

# ---------- 256-QAM ----------
sed -i '/set wireless.radio${devidx}.htmode=/a\
			set wireless.radio${devidx}.ldpc=1' "$MAC80211_SH"

# ---------- MU-MIMO ----------
sed -i '/set wireless.radio${devidx}.htmode=/a\
			set wireless.radio${devidx}.mu_beamformer=1' "$MAC80211_SH"

echo "✅ 无线配置修改完成"

# 验证
echo ""
echo "验证配置修改结果..."
grep -q 'noscan=1' "$MAC80211_SH" && echo "  ✓ 强制40MHz模式 (noscan=1)" || echo "  ✗ 强制40MHz失败"
grep -q 'ldpc=1' "$MAC80211_SH" && echo "  ✓ 256-QAM已启用" || echo "  ✗ 256-QAM失败"
grep -q 'mu_beamformer=1' "$MAC80211_SH" && echo "  ✓ MU-MIMO已启用" || echo "  ✗ MU-MIMO失败"
grep -q 'ssid="铁哥中继器-2.4G"' "$MAC80211_SH" && echo "  ✓ SSID已修改" || echo "  ✗ SSID失败"

echo ""
echo "========================================="
echo "配置摘要:"
echo "  - 主机名: WiFirepeater | IP: 192.168.66.1"
echo "  - NTP: 已启用（使用系统默认服务器列表）"
echo "  - 2.4G SSID: 铁哥中继器-2.4G | 信道: 自动"
echo "  - 强制40MHz + 256-QAM + MU-MIMO"
echo "  - 2.4G 功率: 驱动自动配置"
echo "  - 5G SSID: 铁哥中继器-5G"
echo "========================================="
