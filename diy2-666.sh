#!/bin/bash
# 文件名: diy2.sh
# 功能: 修改 ImmortalWrt 的默认配置（系统、网络、无线）

set -e  # 遇到错误立即退出

echo "开始执行 DIY 脚本..."
echo "当前工作目录: $(pwd)"
echo "========================================="

# ==================== 0. 创建必要目录 ====================
mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults
echo "✅ 创建必要目录完成"

# ==================== 1. System 配置 ====================
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
echo "✅ System 配置完成"

# ==================== 2. 默认 IP 修改 ====================
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
    echo "✅ IP 修改完成 (192.168.1.1 → 192.168.66.1)"
else
    echo "⚠️ 警告: config_generate 文件不存在"
fi

# ==================== 3. 无线配置修改 ====================
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ ! -f "$MAC80211_SH" ]; then
    echo "错误: 找不到 $MAC80211_SH"
    find package -name "mac80211.sh" 2>/dev/null
    exit 1
fi

echo "找到无线配置文件: $MAC80211_SH"

cp "$MAC80211_SH" "$MAC80211_SH.bak"
echo "已备份原文件"

# 修改1: 国家代码 CN -> US
sed -i 's/set wireless.radio${devidx}.country=CN/set wireless.radio${devidx}.country=US/g' "$MAC80211_SH"

# 修改2: 2.4G 信道改为 auto（5G 信道不做修改，保持原样）
# 注意：原代码中信道是通过 ${channel} 变量设置的，这个变量来自 get_band_defaults 函数
# 我们需要在 2.4G 时覆盖这个变量，5G 时保持原值
sed -i '/uci -q batch <<-EOF/i\
		# 2.4G 信道设置为 auto，5G 保持默认\
		if [ "${mode_band}" = "2g" ]; then\
			channel="auto"\
		fi\
' "$MAC80211_SH"

# 修改3: 添加功率判断（2.4G=18，5G 不设置，使用驱动默认）
sed -i '/uci -q batch <<-EOF/i\
		# 根据频段设置不同的发射功率（5G 不设置，使用驱动默认）\
		if [ "${mode_band}" = "2g" ]; then\
			txpower_val="18"\
		fi\
' "$MAC80211_SH"

# 修改4: SSID 区分
sed -i '/uci -q batch <<-EOF/i\
		# 根据频段设置不同的 SSID\
		if [ "${mode_band}" = "2g" ]; then\
			ssid="铁哥中继器-2.4G"\
		else\
			ssid="铁哥中继器-5G"\
		fi\
' "$MAC80211_SH"

# 修改5: 将 SSID 行改为使用变量
sed -i 's/set wireless.default_radio${devidx}.ssid=ImmortalWrt/set wireless.default_radio${devidx}.ssid=${ssid}/g' "$MAC80211_SH"

# 修改6: 带宽设置（2.4G=HT40，5G 保持原样）
sed -i '/uci -q batch <<-EOF/i\
		# 2.4G 带宽设置为 HT40，5G 保持默认\
		if [ "${mode_band}" = "2g" ]; then\
			htmode="HT40"\
		fi\
' "$MAC80211_SH"

# 修改7: 添加 mu_beamformer 和 cell_density（两个频段都启用）
sed -i '/set wireless.radio${devidx}.htmode=/a\
			set wireless.radio${devidx}.cell_density=0\
			set wireless.radio${devidx}.mu_beamformer=1' "$MAC80211_SH"

echo "✅ 无线配置已修改"

# 验证修改
echo ""
echo "验证无线配置修改结果..."

VERIFY_FAILED=0

# 验证1: 国家代码
if grep -q 'country=US' "$MAC80211_SH"; then
    echo "  ✓ 国家代码已修改为 US"
else
    echo "  ✗ 国家代码修改失败"
    VERIFY_FAILED=1
fi

# 验证2: 2.4G 信道 auto
if grep -q 'channel="auto"' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 信道已设置为 auto"
else
    echo "  ✗ 2.4G 信道设置失败"
    VERIFY_FAILED=1
fi

# 验证3: 2.4G 功率
if grep -q 'txpower_val="18"' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 功率已设置为 18dBm"
else
    echo "  ✗ 2.4G 功率设置失败"
    VERIFY_FAILED=1
fi

# 验证4: SSID 区分
if grep -q 'ssid="铁哥中继器-2.4G"' "$MAC80211_SH" && grep -q 'ssid="铁哥中继器-5G"' "$MAC80211_SH"; then
    echo "  ✓ SSID 区分逻辑已添加"
else
    echo "  ✗ SSID 区分逻辑失败"
    VERIFY_FAILED=1
fi

# 验证5: 2.4G 带宽 HT40
if grep -q 'htmode="HT40"' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 带宽已设置为 HT40"
else
    echo "  ✗ 2.4G 带宽设置失败"
    VERIFY_FAILED=1
fi

# 验证6: mu_beamformer
if grep -q 'mu_beamformer=1' "$MAC80211_SH"; then
    echo "  ✓ mu_beamformer 已启用"
else
    echo "  ✗ mu_beamformer 设置失败"
    VERIFY_FAILED=1
fi

# 验证7: 确保没有错误修改 5G 信道为 auto
if grep -q 'else.*channel="auto"' "$MAC80211_SH"; then
    echo "  ✗ 警告: 5G 信道可能被错误设置为 auto"
    VERIFY_FAILED=1
else
    echo "  ✓ 5G 信道保持默认（未修改）"
fi

if [ $VERIFY_FAILED -ne 0 ]; then
    echo ""
    echo "错误: 无线配置修改验证失败，编译终止"
    cp "$MAC80211_SH.bak" "$MAC80211_SH"
    exit 1
fi

echo "✅ 所有配置修改成功验证"
echo ""
echo "========================================="
echo "配置摘要:"
echo "  - 主机名: WiFirepeater"
echo "  - 管理 IP: 192.168.66.1"
echo "  - 国家代码: US"
echo "  - 2.4G: 铁哥中继器-2.4G | 信道: auto | 带宽: HT40 | 功率: 18dBm"
echo "  - 5G: 铁哥中继器-5G | 信道: 默认 | 带宽: 默认 | 功率: 默认"
echo "  - MU-MIMO: 启用"
echo "========================================="

exit 0
