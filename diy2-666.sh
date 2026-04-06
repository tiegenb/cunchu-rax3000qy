#!/bin/bash
# ==================== diy2-666.sh ====================

# 创建必要目录
mkdir -p files/etc/config
mkdir -p files/etc/config/system
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

# ==================== 检查并修复源码中的无线配置 ====================
echo "=========================================="
echo "检查并修复源码中的无线配置..."
echo "=========================================="

# 查找 mac80211.sh 文件
MAC80211_SH=""
if [ -f "package/kernel/mac80211/files/lib/wifi/mac80211.sh" ]; then
    MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"
elif [ -f "package/kernel/mac80211/files/lib/netifd/wireless/mac80211.sh" ]; then
    MAC80211_SH="package/kernel/mac80211/files/lib/netifd/wireless/mac80211.sh"
else
    echo "❌ 错误: 找不到 mac80211.sh 文件"
    exit 1
fi

echo "找到文件: $MAC80211_SH"

# 检查是否包含 disabled=0
if grep -q "set wireless.radio\${devidx}.disabled=0" "$MAC80211_SH"; then
    echo "✅ 已存在 disabled=0，无需修复"
else
    echo "⚠️ 未找到 disabled=0，尝试自动修复..."
    
    # 尝试修复：将 disabled=1 改为 disabled=0
    if grep -q "set wireless.radio\${devidx}.disabled=1" "$MAC80211_SH"; then
        sed -i 's/set wireless.radio\${devidx}.disabled=1/set wireless.radio\${devidx}.disabled=0/g' "$MAC80211_SH"
        echo "🔧 已将 disabled=1 改为 disabled=0"
    else
        # 如果没有 disabled=1，尝试在合适的位置添加 disabled=0
        echo "⚠️ 未找到 disabled=1，尝试添加 disabled=0..."
        # 在 htmode 设置后面添加 disabled=0
        sed -i '/set wireless.radio${devidx}.htmode=/a \\t\t\tset wireless.radio${devidx}.disabled=0' "$MAC80211_SH"
    fi
    
    # 验证修复是否成功
    if grep -q "set wireless.radio\${devidx}.disabled=0" "$MAC80211_SH"; then
        echo "✅ 修复成功: 已添加 disabled=0"
    else
        echo "❌ 修复失败: 无法添加 disabled=0"
        echo "   请手动检查 $MAC80211_SH 文件"
        exit 1
    fi
fi

# 额外检查是否有 disabled=1 残留
if grep -q "set wireless.radio\${devidx}.disabled=1" "$MAC80211_SH"; then
    echo "❌ 错误: 仍存在 disabled=1 配置"
    echo "   请手动检查 $MAC80211_SH 文件"
    exit 1
else
    echo "✅ 确认无 disabled=1 冲突"
fi

echo "=========================================="
echo ""

# ==================== 3. 强制启用脚本（备用保险） ====================
cat > files/etc/uci-defaults/99-enable-wifi << 'EOF'
#!/bin/sh
sleep 3
uci set wireless.radio0.disabled=0
uci set wireless.radio1.disabled=0
uci commit wireless
/etc/init.d/network restart
exit 0
EOF
chmod +x files/etc/uci-defaults/99-enable-wifi
echo "✅ 已添加无线强制启用脚本"

# ==================== 完成 ====================
echo "=========================================="
echo "✅ 所有配置完成，继续编译"
echo "=========================================="
