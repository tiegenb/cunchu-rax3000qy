#!/bin/bash
# ==================== diy2-666.sh ====================

# 创建必要目录
mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults
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
# 定义目标文件路径
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

# 检查文件是否存在
if [ ! -f "$MAC80211_SH" ]; then
    echo "错误: 找不到 $MAC80211_SH"
    echo "当前目录: $(pwd)"
    exit 1
fi

echo "找到无线配置文件: $MAC80211_SH"

# 备份原文件
cp "$MAC80211_SH" "$MAC80211_SH.bak"
echo "已备份原文件"

# 使用 cat 来替换整个 detect_mac80211 函数
# 获取函数开始和结束的行号
START_LINE=$(grep -n "^detect_mac80211() {" "$MAC80211_SH" | cut -d: -f1)
END_LINE=$(grep -n "^}" "$MAC80211_SH" | awk -F: -v start="$START_LINE" '$1 > start {print $1; exit}')

if [ -z "$START_LINE" ] || [ -z "$END_LINE" ]; then
    echo "错误: 无法定位 detect_mac80211 函数"
    exit 1
fi

# 保存函数之前和之后的内容
head -n $((START_LINE - 1)) "$MAC80211_SH" > /tmp/mac80211_head
tail -n +$((END_LINE + 1)) "$MAC80211_SH" > /tmp/mac80211_tail

# 写入修改后的函数（信道设置为 auto）
cat > /tmp/mac80211_function << 'EOF'
detect_mac80211() {
	devidx=0
	config_load wireless
	while :; do
		config_get type "radio$devidx" type
		[ -n "$type" ] || break
		devidx=$(($devidx + 1))
	done

	for _dev in /sys/class/ieee80211/*; do
		[ -e "$_dev" ] || continue

		dev="${_dev##*/}"

		found=0
		config_foreach check_mac80211_device wifi-device
		[ "$found" -gt 0 ] && continue

		mode_band=""
		channel=""
		htmode=""
		ht_capab=""

		get_band_defaults "$dev"

		path="$(iwinfo nl80211 path "$dev")"
		if [ -n "$path" ]; then
			dev_id="set wireless.radio${devidx}.path='$path'"
		else
			dev_id="set wireless.radio${devidx}.macaddr=$(cat /sys/class/ieee80211/${dev}/macaddress)"
		fi

		# 根据频段设置不同的发射功率
		if [ "${mode_band}" = "2g" ]; then
			txpower_val="18"
		else
			txpower_val="28"
		fi

		uci -q batch <<-EOF
			set wireless.radio${devidx}=wifi-device
			set wireless.radio${devidx}.type=mac80211
			${dev_id}
			set wireless.radio${devidx}.channel=auto
			set wireless.radio${devidx}.band=${mode_band}
			set wireless.radio${devidx}.htmode=${htmode}
			set wireless.radio${devidx}.country=US
			set wireless.radio${devidx}.disabled=0
			set wireless.radio${devidx}.txpower=${txpower_val}
			set wireless.radio${devidx}.cell_density=0
			set wireless.radio${devidx}.mu_beamformer=1

			set wireless.default_radio${devidx}=wifi-iface
			set wireless.default_radio${devidx}.device=radio${devidx}
			set wireless.default_radio${devidx}.network=lan
			set wireless.default_radio${devidx}.mode=ap
			set wireless.default_radio${devidx}.ssid=铁哥中继器
			set wireless.default_radio${devidx}.encryption=none
EOF
		uci -q commit wireless

		devidx=$(($devidx + 1))
	done
}
EOF

# 重新组合文件
cat /tmp/mac80211_head /tmp/mac80211_function /tmp/mac80211_tail > "$MAC80211_SH"

# 清理临时文件
rm -f /tmp/mac80211_head /tmp/mac80211_tail /tmp/mac80211_function

echo "✅ 无线配置已修改（信道=auto，2.4G功率=18，5G功率=28）"

# 验证无线配置修改
echo ""
echo "验证无线配置修改结果..."

VERIFY_FAILED=0

# 验证1: 信道设置为 auto
if grep -q 'set wireless.radio${devidx}.channel=auto' "$MAC80211_SH"; then
    echo "  ✓ 信道已设置为 auto（自动）"
else
    echo "  ✗ 信道设置失败"
    VERIFY_FAILED=1
fi

# 验证2: 国家代码
if grep -q "set wireless.radio\${devidx}.country=US" "$MAC80211_SH"; then
    echo "  ✓ 国家代码已修改为 US"
else
    echo "  ✗ 国家代码修改失败"
    VERIFY_FAILED=1
fi

# 验证3: SSID
if grep -q "set wireless.default_radio\${devidx}.ssid=铁哥中继器" "$MAC80211_SH"; then
    echo "  ✓ SSID 已修改为「铁哥中继器」"
else
    echo "  ✗ SSID 修改失败"
    VERIFY_FAILED=1
fi

# 验证4: 2.4G 功率判断逻辑
if grep -q 'if \[ "${mode_band}" = "2g" \]; then' "$MAC80211_SH" && grep -q 'txpower_val="18"' "$MAC80211_SH"; then
    echo "  ✓ 2.4G 功率逻辑已添加 (18dBm)"
else
    echo "  ✗ 2.4G 功率逻辑添加失败"
    VERIFY_FAILED=1
fi

# 验证5: 5G 功率
if grep -q 'txpower_val="28"' "$MAC80211_SH"; then
    echo "  ✓ 5G 功率逻辑已添加 (28dBm)"
else
    echo "  ✗ 5G 功率逻辑添加失败"
    VERIFY_FAILED=1
fi

# 验证6: mu_beamformer
if grep -q "set wireless.radio\${devidx}.mu_beamformer=1" "$MAC80211_SH"; then
    echo "  ✓ mu_beamformer 已启用"
else
    echo "  ✗ mu_beamformer 设置失败"
    VERIFY_FAILED=1
fi

# 验证7: cell_density
if grep -q "set wireless.radio\${devidx}.cell_density=0" "$MAC80211_SH"; then
    echo "  ✓ cell_density 已设置为 0"
else
    echo "  ✗ cell_density 设置失败"
    VERIFY_FAILED=1
fi

# 如果无线配置验证失败，退出编译
if [ $VERIFY_FAILED -ne 0 ]; then
    echo ""
    echo "错误: 无线配置修改验证失败，编译终止"
    # 恢复原文件
    cp "$MAC80211_SH.bak" "$MAC80211_SH"
    exit 1
fi

echo "✅ 无线配置修改成功验证"
