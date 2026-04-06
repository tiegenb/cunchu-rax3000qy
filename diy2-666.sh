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

# ==================== 3. 无线配置修改（纯文本替换）====================
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ ! -f "$MAC80211_SH" ]; then
    echo "错误: 找不到 $MAC80211_SH"
    echo "尝试查找文件位置..."
    find package -name "mac80211.sh" 2>/dev/null || echo "未找到"
    exit 1
fi

echo "找到无线配置文件: $MAC80211_SH"

# 备份原文件
cp "$MAC80211_SH" "$MAC80211_SH.bak"
echo "已备份原文件"

# 修改1: 国家代码 CN -> US
sed -i 's/set wireless.radio${devidx}.country=CN/set wireless.radio${devidx}.country=US/g' "$MAC80211_SH"

# 修改2: 默认 SSID ImmortalWrt -> 铁哥中继器
sed -i 's/set wireless.default_radio${devidx}.ssid=ImmortalWrt/set wireless.default_radio${devidx}.ssid=铁哥中继器/g' "$MAC80211_SH"

# 修改3: 信道从 ${channel} 改为 auto
sed -i 's/set wireless.radio${devidx}.channel=${channel}/set wireless.radio${devidx}.channel=auto/g' "$MAC80211_SH"

# 修改4: 在 htmode 行后添加 txpower、cell_density、mu_beamformer
sed -i '/set wireless.radio${devidx}.htmode=/a\
			set wireless.radio${devidx}.txpower=${txpower_val}\
			set wireless.radio${devidx}.cell_density=0\
			set wireless.radio${devidx}.mu_beamformer=1' "$MAC80211_SH"

# 修改5: 在 uci batch 块之前添加功率判断逻辑
sed -i '/uci -q batch <<-EOF/i\
		# 根据频段设置不同的发射功率\
		if [ "${mode_band}" = "2g" ]; then\
			txpower_val="18"\
		else\
			txpower_val="28"\
		fi\
' "$MAC80211_SH"

echo "✅ 无线配置已修改（纯文本替换完成）"

# 验证修改
echo ""
echo "验证无线配置修改结果..."

VERIFY_FAILED=0

# 验证1: 信道
if grep -q 'set wireless.radio${devidx}.channel=auto' "$MAC80211_SH"; then
    echo "  ✓ 信道已设置为 auto"
else
    echo "  ✗ 信道设置失败"
    VERIFY_FAILED=1
fi

# 验证2: 国家代码
if grep -q 'set wireless.radio${devidx}.country=US' "$MAC80211_SH"; then
    echo "  ✓ 国家代码已修改为 US"
else
    echo "  ✗ 国家代码修改失败"
    VERIFY_FAILED=1
fi

# 验证3: SSID
if grep -q 'set wireless.default_radio${devidx}.ssid=铁哥中继器' "$MAC80211_SH"; then
    echo "  ✓ SSID 已修改为「铁哥中继器」"
else
    echo "  ✗ SSID 修改失败"
    VERIFY_FAILED=1
fi

# 验证4: 功率判断逻辑
if grep -q 'txpower_val="18"' "$MAC80211_SH" && grep -q 'txpower_val="28"' "$MAC80211_SH"; then
    echo "  ✓ 功率判断逻辑已添加 (2.4G=18, 5G=28)"
else
    echo "  ✗ 功率判断逻辑添加失败"
    VERIFY_FAILED=1
fi

# 验证5: mu_beamformer
if grep -q 'mu_beamformer=1' "$MAC80211_SH"; then
    echo "  ✓ mu_beamformer 已启用"
else
    echo "  ✗ mu_beamformer 设置失败"
    VERIFY_FAILED=1
fi

# 验证6: cell_density
if grep -q 'cell_density=0' "$MAC80211_SH"; then
    echo "  ✓ cell_density 已设置为 0"
else
    echo "  ✗ cell_density 设置失败"
    VERIFY_FAILED=1
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
echo "  - 时区: Asia/Shanghai"
echo "  - 国家代码: US"
echo "  - Wi-Fi SSID: 铁哥中继器"
echo "  - 2.4G 功率: 18dBm"
echo "  - 5G 功率: 28dBm"
echo "  - 信道: auto"
echo "  - MU-MIMO: 启用"
echo "========================================="

exit 0
