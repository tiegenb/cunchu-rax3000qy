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

# ==================== 3. 无线配置修改 ====================
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ ! -f "$MAC80211_SH" ]; then
    echo "错误: 找不到 $MAC80211_SH"
    exit 1
fi

cp "$MAC80211_SH" "$MAC80211_SH.bak"

# ---------- 1. SSID 修改（2.4G 和 5G）----------
# 直接替换默认的 ssid=ImmortalWrt 为固定名称
sed -i 's/set wireless.default_radio${devidx}.ssid=ImmortalWrt/set wireless.default_radio${devidx}.ssid=铁哥中继器/g' "$MAC80211_SH"

# ---------- 2. 2.4G 模式改为 HE40 ----------
# 直接修改 htmode 变量的赋值逻辑
sed -i '/case "$mode_band" in/,/esac/ {
    /2g)/ s/htmode="[^"]*"/htmode="HE40"/
    /5g)/ s/htmode="[^"]*"/htmode=""/
}' "$MAC80211_SH"

# ---------- 3. 2.4G 强制40MHz (noscan=1) ----------
# 在 uci batch 块内，htmode 设置之后添加 noscan
sed -i '/set wireless.radio${devidx}.htmode=/a\
			[ "$mode_band" = "2g" ] && set wireless.radio${devidx}.noscan=1' "$MAC80211_SH"

# ---------- 4. 2.4G 256-QAM (ldpc=1) ----------
sed -i '/set wireless.radio${devidx}.htmode=/a\
			[ "$mode_band" = "2g" ] && set wireless.radio${devidx}.ldpc=1' "$MAC80211_SH"

# ---------- 5. MU-MIMO（双频都启用）----------
sed -i '/set wireless.radio${devidx}.htmode=/a\
			set wireless.radio${devidx}.mu_beamformer=1' "$MAC80211_SH"

echo "✅ 无线配置修改完成"

# 验证
echo ""
echo "验证配置修改结果..."

grep -q 'htmode="HE40"' "$MAC80211_SH" && echo "  ✓ 2.4G 模式: HE40" || echo "  ✗ 2.4G HE40 失败"
grep -q 'noscan=1' "$MAC80211_SH" && echo "  ✓ 2.4G 强制40MHz" || echo "  ✗ 强制40MHz 失败"
grep -q 'ldpc=1' "$MAC80211_SH" && echo "  ✓ 2.4G 256-QAM" || echo "  ✗ 256-QAM 失败"
grep -q 'mu_beamformer=1' "$MAC80211_SH" && echo "  ✓ MU-MIMO" || echo "  ✗ MU-MIMO 失败"

echo ""
echo "========================================="
echo "配置摘要:"
echo "  - 主机名: WiFirepeater | IP: 192.168.66.1"
echo "  - 2.4G: 铁哥中继器 | HE40 | 强制40MHz | 256-QAM | MU-MIMO"
echo "  - 5G: 铁哥中继器 | MU-MIMO"
echo "  - 其余配置: 驱动自动"
echo "========================================="
