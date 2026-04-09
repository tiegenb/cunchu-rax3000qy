#!/bin/bash
# 文件名: diy2.sh

set -e

echo "开始执行 DIY 脚本..."
echo "========================================="

# ==================== 0. 创建必要目录 ====================
mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults

# ==================== 1. System 配置（主机名） ====================
cat > files/etc/config/system << 'EOF'
config system
    option hostname 'WiFirepeater'
    option zonename 'Asia/Shanghai'
    option timezone 'CST-8'

config timeserver 'ntp'
    option enabled '1'

EOF
echo "✅ 主机名: WiFirepeater"

# ==================== 2. 默认 IP 修改 ====================
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
    echo "✅ 管理 IP: 192.168.66.1"
fi

# ---------- 无线配置修改（统一处理）----------
# 1. SSID 修改（根据频段区分）
sed -i '/set wireless.default_radio${devidx}.ssid=ImmortalWrt/d' "$MAC80211_SH"
sed -i '/uci -q commit wireless/i\
		# 自定义 SSID（根据频段区分）\
		if [ "$mode_band" = "2g" ]; then\
			uci set wireless.default_radio${devidx}.ssid="铁哥中继器-2.4G"\
		else\
			uci set wireless.default_radio${devidx}.ssid="铁哥中继器-5G"\
		fi\
' "$MAC80211_SH"

# 2. 2.4G & 5G 专属配置（在 commit 前用 uci set 覆盖）
sed -i '/uci -q commit wireless/i\
		# 2.4G 信道自动\
		if [ "$mode_band" = "2g" ]; then\
			uci set wireless.radio${devidx}.channel="auto"\
		fi\
		# 2.4G 配置（HE40）\
		if [ "$mode_band" = "2g" ]; then\
			uci set wireless.radio${devidx}.htmode="HE40"\
		fi\
		# MU-MIMO 双频启用\
		uci set wireless.radio${devidx}.mu_beamformer=1\
' "$MAC80211_SH"

echo "✅ 无线配置修改完成"

# 验证
echo ""
echo "验证配置修改结果..."
grep -q 'uci set wireless.default_radio${devidx}.ssid="铁哥中继器-2.4G"' "$MAC80211_SH" || { echo "✗ 2.4G SSID 失败"; exit 1; }
grep -q 'uci set wireless.default_radio${devidx}.ssid="铁哥中继器-5G"' "$MAC80211_SH" || { echo "✗ 5G SSID 失败"; exit 1; }
grep -q 'uci set wireless.radio${devidx}.htmode="HE40"' "$MAC80211_SH" || { echo "✗ HE40 失败"; exit 1; }
grep -q 'uci set wireless.radio${devidx}.channel="auto"' "$MAC80211_SH" || { echo "✗ 信道自动 失败"; exit 1; }
grep -q 'uci set wireless.radio${devidx}.mu_beamformer=1' "$MAC80211_SH" || { echo "✗ MU-MIMO 失败"; exit 1; }
echo "✓ 所有配置验证通过"

echo ""
echo "========================================="
echo "配置摘要:"
echo "  - 主机名: WiFirepeater | IP: 192.168.66.1"
echo "  - 2.4G: 铁哥中继器-2.4G | 信道自动 | HE40 | MU-MIMO"
echo "  - 5G: 铁哥中继器-5G | MU-MIMO"
echo "========================================="
