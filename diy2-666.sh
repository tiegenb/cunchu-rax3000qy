#!/bin/bash
# 文件名: diy2.sh
# 功能: 修改 ImmortalWrt 的默认配置（仅保留指定项）

set -e

echo "开始执行 DIY 脚本..."
echo "当前工作目录: $(pwd)"
echo "========================================="

# ==================== 0. 创建必要目录 ====================
mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults
echo "✅ 创建必要目录完成"

# ==================== 1. System 配置（主机名） ====================
cat > files/etc/config/system << 'EOF'
config system
    option hostname 'WiFirepeater'
    option zonename 'Asia/Shanghai'
    option timezone 'CST-8'

config timeserver 'ntp'
    option enabled '0'
    option enable_server '0'
EOF
echo "✅ 主机名: WiFirepeater"

# ==================== 2. 默认 IP 修改 ====================
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
    echo "✅ 管理 IP: 192.168.66.1"
else
    echo "⚠️ 警告: config_generate 文件不存在"
fi

# ==================== 3. 无线配置修改 ====================
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ ! -f "$MAC80211_SH" ]; then
    echo "错误: 找不到 $MAC80211_SH"
    exit 1
fi

echo "找到无线配置文件: $MAC80211_SH"
cp "$MAC80211_SH" "$MAC80211_SH.bak"

# 修改1: SSID 区分（2.4G 和 5G）
sed -i '/uci -q batch <<-EOF/i\
		# 自定义 SSID\
		if [ "${mode_band}" = "2g" ]; then\
			ssid="铁哥中继器-2.4G"\
		else\
			ssid="铁哥中继器-5G"\
		fi\
' "$MAC80211_SH"

# 修改2: 将 SSID 行改为使用变量
sed -i 's/set wireless.default_radio${devidx}.ssid=ImmortalWrt/set wireless.default_radio${devidx}.ssid=${ssid}/g' "$MAC80211_SH"

# 修改3: 2.4G 功率设置为 18dBm
sed -i '/uci -q batch <<-EOF/i\
		# 2.4G 发射功率\
		if [ "${mode_band}" = "2g" ]; then\
			txpower_val="18"\
		fi\
' "$MAC80211_SH"

# 修改4: 启用 MU-MIMO（双频）
sed -i '/set wireless.radio${devidx}.htmode=/a\
			set wireless.radio${devidx}.mu_beamformer=1' "$MAC80211_SH"

echo "✅ 无线配置修改完成"

# 验证修改
echo ""
echo "验证配置修改结果..."

VERIFY_FAILED=0

if grep -q 'ssid="铁哥中继器-2.4G"' "$MAC80211_SH"; then
    echo "  ✓ 2.4G SSID: 铁哥中继器-2.4G"
else
    echo "  ✗ 2.4G SSID 设置失败"
    VERIFY_FAILED=1
fi

if grep -q 'ssid="铁哥中继器-5G"' "$MAC80211_SH"; then
    echo "  ✓ 5G SSID: 铁哥中继器-5G"
else
    echo "  ✗ 5G SSID 设置失败"
    VERIFY_FAILED=1
fi

if grep -q 'txpower_val="18"' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 功率: 18dBm"
else
    echo "  ✗ 2.4G 功率设置失败"
    VERIFY_FAILED=1
fi

if grep -q 'mu_beamformer=1' "$MAC80211_SH"; then
    echo "  ✓ MU-MIMO: 双频已启用"
else
    echo "  ✗ MU-MIMO 设置失败"
    VERIFY_FAILED=1
fi

if [ $VERIFY_FAILED -ne 0 ]; then
    echo ""
    echo "错误: 配置修改验证失败，编译终止"
    cp "$MAC80211_SH.bak" "$MAC80211_SH"
    exit 1
fi

echo ""
echo "========================================="
echo "配置摘要（保留项）:"
echo "  - 主机名: WiFirepeater"
echo "  - 管理 IP: 192.168.66.1"
echo "  - 2.4G SSID: 铁哥中继器-2.4G | 功率: 18dBm"
echo "  - 5G SSID: 铁哥中继器-5G"
echo "  - MU-MIMO: 双频启用"
echo "  - 其余配置（国家代码、信道、带宽等）: 使用驱动默认值"
echo "========================================="
