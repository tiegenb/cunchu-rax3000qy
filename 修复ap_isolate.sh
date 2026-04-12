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

# ==================== 3. 修复 hostapd ap_isolate ====================
echo ""
echo "=== 修复 hostapd ap_isolate 问题 ==="

HOSTAPD_SH="package/network/services/hostapd/files/hostapd.sh"
if [ -f "$HOSTAPD_SH" ]; then
    # 将 ap_isolate=$isolate 改为 ap_isolate=0（保持语法完整）
    sed -i 's/append bss_conf "ap_isolate=\$isolate"/append bss_conf "ap_isolate=0"/' "$HOSTAPD_SH"
    echo "✓ hostapd ap_isolate 修复完成"
else
    echo "⚠ 未找到 hostapd.sh"
fi

# ==================== 4. 无线配置修改 ====================
echo ""
echo "=== 修改无线配置 ==="

# 定义 MAC80211_SH 变量（关键！必须在修改之前定义）
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

# 检查文件是否存在，如果不存在则尝试其他路径
if [ ! -f "$MAC80211_SH" ]; then
    MAC80211_SH="package/network/services/hostapd/files/mac80211.sh"
fi

if [ ! -f "$MAC80211_SH" ]; then
    echo "⚠ 未找到 mac80211.sh，跳过无线配置"
else
    echo "找到文件: $MAC80211_SH"
    
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
fi

# ==================== 5. 创建开机备用修复脚本（双重保险） ====================
cat > files/etc/uci-defaults/99-fix-ap-isolate << 'EOF'
#!/bin/sh
sleep 3
if ls /var/run/hostapd-phy*.conf >/dev/null 2>&1; then
    if grep -q "ap_isolate=1" /var/run/hostapd-phy*.conf 2>/dev/null; then
        sed -i 's/ap_isolate=1/ap_isolate=0/g' /var/run/hostapd-phy*.conf 2>/dev/null
        /etc/init.d/hostapd restart 2>/dev/null
    fi
fi
exit 0
EOF
chmod +x files/etc/uci-defaults/99-fix-ap-isolate
echo "✅ 创建开机备用修复脚本"

echo ""
echo "========================================="
echo "配置摘要:"
echo "  - 主机名: WiFirepeater | IP: 192.168.66.1"
echo "  - 2.4G: 铁哥中继器-2.4G | 信道自动 | HE40 | MU-MIMO"
echo "  - 5G: 铁哥中继器-5G | MU-MIMO"
echo "  - ap_isolate: 已修复 (强制 ap_isolate=0)"
echo "========================================="
