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
else
    echo "❌ 错误: 找不到 config_generate 文件"
    exit 1
fi

# ==================== 3. 无线配置修改 ====================
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ ! -f "$MAC80211_SH" ]; then
    echo "❌ 错误: 找不到 $MAC80211_SH"
    exit 1
fi

cp "$MAC80211_SH" "$MAC80211_SH.bak"
echo "找到无线配置文件: $MAC80211_SH"

# ------------------------------------------------------------
# 修改1: 2.4G 信道改为 auto
# ------------------------------------------------------------
sed -i '/set wireless.radio${devidx}.htmode=$htmode/a\
			# 2.4G 信道覆盖为 auto\
			if [ "${mode_band}" = "2g" ]; then\
				set wireless.radio${devidx}.channel="auto"\
			fi' "$MAC80211_SH"

# ------------------------------------------------------------
# 修改2: SSID 修改
# ------------------------------------------------------------
sed -i '/set wireless.default_radio${devidx}.ssid=ImmortalWrt/a\
			# 根据频段设置不同的 SSID\
			if [ "${mode_band}" = "2g" ]; then\
				set wireless.default_radio${devidx}.ssid="铁哥中继器-2.4G"\
			else\
				set wireless.default_radio${devidx}.ssid="铁哥中继器-5G"\
			fi' "$MAC80211_SH"

# 注释掉原来的 ssid 行
sed -i 's/set wireless.default_radio${devidx}.ssid=ImmortalWrt/# set wireless.default_radio${devidx}.ssid=ImmortalWrt/g' "$MAC80211_SH"

# ------------------------------------------------------------
# 修改3: 2.4G + 5G 配置（合并，避免互相覆盖）
# ------------------------------------------------------------
sed -i '/set wireless.radio${devidx}.htmode=$htmode/a\
			# 2.4G 专属配置（802.11ax / Wi-Fi 6）\
			if [ "${mode_band}" = "2g" ]; then\
				set wireless.radio${devidx}.noscan=1\
				set wireless.radio${devidx}.htmode="HE40"\
				set wireless.radio${devidx}.ldpc=1\
				set wireless.radio${devidx}.mu_beamformer=1\
			fi\
			# 5G MU-MIMO\
			if [ "${mode_band}" = "5g" ]; then\
				set wireless.radio${devidx}.mu_beamformer=1\
			fi' "$MAC80211_SH"

echo ""
echo "========================================="
echo "验证配置修改结果..."
echo "========================================="

VERIFY_FAILED=0

# 验证 2.4G 信道 auto
if grep -q 'set wireless.radio${devidx}.channel="auto"' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 信道: auto"
else
    echo "  ✗ 2.4G 信道 auto 设置失败"
    VERIFY_FAILED=1
fi

# 验证 SSID
if grep -q '铁哥中继器-2.4G' "$MAC80211_SH"; then
    echo "  ✓ 2.4G SSID: 铁哥中继器-2.4G"
else
    echo "  ✗ 2.4G SSID 设置失败"
    VERIFY_FAILED=1
fi

if grep -q '铁哥中继器-5G' "$MAC80211_SH"; then
    echo "  ✓ 5G SSID: 铁哥中继器-5G"
else
    echo "  ✗ 5G SSID 设置失败"
    VERIFY_FAILED=1
fi

# 验证 2.4G 强制40MHz
if grep -q 'set wireless.radio${devidx}.noscan=1' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 强制40MHz (noscan=1)"
else
    echo "  ✗ 2.4G 强制40MHz 设置失败"
    VERIFY_FAILED=1
fi

# 验证 2.4G AX模式
if grep -q 'set wireless.radio${devidx}.htmode="HE40"' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 模式: 802.11ax (HE40)"
else
    echo "  ✗ 2.4G AX模式 设置失败"
    VERIFY_FAILED=1
fi

# 验证 2.4G 256-QAM
if grep -q 'set wireless.radio${devidx}.ldpc=1' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 256-QAM (ldpc=1)"
else
    echo "  ✗ 2.4G 256-QAM 设置失败"
    VERIFY_FAILED=1
fi

# 验证 MU-MIMO
if grep -q 'set wireless.radio${devidx}.mu_beamformer=1' "$MAC80211_SH"; then
    echo "  ✓ MU-MIMO 已配置"
else
    echo "  ✗ MU-MIMO 设置失败"
    VERIFY_FAILED=1
fi

# 验证 5G 没有被错误设置 noscan 或 HE40
if grep -A10 'mode_band" = "5g"' "$MAC80211_SH" | grep -q 'noscan'; then
    echo "  ✗ 错误: 5G 被错误设置了 noscan"
    VERIFY_FAILED=1
else
    echo "  ✓ 5G 未被错误设置 noscan"
fi

if grep -A10 'mode_band" = "5g"' "$MAC80211_SH" | grep -q 'HE40'; then
    echo "  ✗ 错误: 5G 被错误设置了 HE40"
    VERIFY_FAILED=1
else
    echo "  ✓ 5G 未被错误设置 HE40"
fi

# 最终结果
if [ $VERIFY_FAILED -ne 0 ]; then
    echo ""
    echo "❌ 配置修改验证失败，编译终止"
    cp "$MAC80211_SH.bak" "$MAC80211_SH"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ 所有配置验证通过"
echo "========================================="
echo "配置摘要:"
echo "  - 主机名: WiFirepeater | IP: 192.168.66.1"
echo "  - 2.4G SSID: 铁哥中继器-2.4G | 信道: auto"
echo "  - 2.4G 模式: 802.11ax (HE40) + 强制40MHz + 256-QAM + MU-MIMO"
echo "  - 5G SSID: 铁哥中继器-5G | MU-MIMO: 启用"
echo "  - 5G 其他配置: 保持驱动默认"
echo "========================================="
