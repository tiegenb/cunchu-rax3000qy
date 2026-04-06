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

# 先清理可能存在的旧修改（避免重复）
sed -i '/# 根据频段设置不同的信道/,/# 根据频段设置不同的 SSID/{ /# 根据频段设置不同的信道/b; /# 根据频段设置不同的 SSID/b; d; }' "$MAC80211_SH" 2>/dev/null || true

# 修改1: 国家代码 CN -> US
sed -i 's/set wireless.radio${devidx}.country=CN/set wireless.radio${devidx}.country=US/g' "$MAC80211_SH"

# 修改2: 将原来的 channel 变量替换为 channel_val（先替换，后面会定义）
sed -i 's/set wireless.radio${devidx}.channel=${channel}/set wireless.radio${devidx}.channel=${channel_val}/g' "$MAC80211_SH"

# 修改3: 将原来的 SSID 替换为 ssid_val
sed -i 's/set wireless.default_radio${devidx}.ssid=ImmortalWrt/set wireless.default_radio${devidx}.ssid=${ssid_val}/g' "$MAC80211_SH"

# 修改4: 在 uci batch 块之前添加所有判断逻辑（一次性添加，避免多次插入）
sed -i '/uci -q batch <<-EOF/i\
		# 根据频段设置不同的信道\
		if [ "${mode_band}" = "2g" ]; then\
			channel_val="auto"\
		else\
			channel_val="48"\
		fi\
		\
		# 根据频段设置不同的 SSID\
		if [ "${mode_band}" = "2g" ]; then\
			ssid_val="铁哥中继器-2.4G"\
		else\
			ssid_val="铁哥中继器-5G"\
		fi\
		\
		# 设置通用参数（cell_density 和 mu_beamformer 两个频段都启用）\
		set wireless.radio${devidx}.cell_density=0\
		set wireless.radio${devidx}.mu_beamformer=1\
		\
		# 只设置 2.4G 的发射功率，5G 保持默认\
		if [ "${mode_band}" = "2g" ]; then\
			set wireless.radio${devidx}.txpower=18\
		fi\
' "$MAC80211_SH"

echo "✅ 无线配置已修改（2.4G功率=18，5G保持默认）"

# 验证修改
echo ""
echo "验证无线配置修改结果..."

VERIFY_FAILED=0

# 验证1: 国家代码
if grep -q 'set wireless.radio${devidx}.country=US' "$MAC80211_SH"; then
    echo "  ✓ 国家代码已修改为 US"
else
    echo "  ✗ 国家代码修改失败"
    VERIFY_FAILED=1
fi

# 验证2: 信道区分逻辑
if grep -q 'channel_val="auto"' "$MAC80211_SH" && grep -q 'channel_val="48"' "$MAC80211_SH"; then
    echo "  ✓ 信道区分逻辑已添加 (2.4G=auto, 5G=48)"
else
    echo "  ✗ 信道区分逻辑添加失败"
    VERIFY_FAILED=1
fi

# 验证3: SSID 区分逻辑
if grep -q 'ssid_val="铁哥中继器-2.4G"' "$MAC80211_SH" && grep -q 'ssid_val="铁哥中继器-5G"' "$MAC80211_SH"; then
    echo "  ✓ SSID 区分逻辑已添加 (2.4G=铁哥中继器-2.4G, 5G=铁哥中继器-5G)"
else
    echo "  ✗ SSID 区分逻辑添加失败"
    VERIFY_FAILED=1
fi

# 验证4: 2.4G 功率设置（检查是否包含 set wireless.radio${devidx}.txpower=18）
if grep -q 'set wireless.radio${devidx}.txpower=18' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 功率已设置为 18dBm"
else
    echo "  ✗ 2.4G 功率设置失败"
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

# 验证7: 确保 5G 没有设置 txpower（检查是否没有 28 或额外的 txpower）
if grep -q 'set wireless.radio${devidx}.txpower=28' "$MAC80211_SH"; then
    echo "  ✗ 警告: 5G 仍设置了发射功率 28（预期为默认值）"
    VERIFY_FAILED=1
else
    echo "  ✓ 5G 发射功率保持默认（未额外设置）"
fi

if [ $VERIFY_FAILED -ne 0 ]; then
    echo ""
    echo "错误: 无线配置修改验证失败，编译终止"
    echo "查看修改后的关键代码片段："
    echo "----------------------------------------"
    grep -A 30 "uci -q batch <<-EOF" "$MAC80211_SH" | head -40
    echo "----------------------------------------"
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
echo "  - 2.4G SSID: 铁哥中继器-2.4G | 信道: auto | 功率: 18dBm"
echo "  - 5G SSID: 铁哥中继器-5G | 信道: 48 | 功率: 默认值"
echo "  - MU-MIMO: 启用"
echo "========================================="

exit 0
