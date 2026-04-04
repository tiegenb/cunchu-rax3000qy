#!/bin/bash
# 多ssid.sh - 编译前配置修改

echo "=========================================="
echo "Starting diy-part1.sh modifications..."
echo "=========================================="

# ============================================
# 1. 配置 wpad-wolfssl（完整版，支持多SSID）
# ============================================
echo ""
echo "1. Configuring wpad-wolfssl (Full version for Multi-SSID)..."

# 禁用所有其他 wpad 变体（直接注释或删除）
for wpad_var in wpad wpad-basic wpad-basic-openssl wpad-basic-wolfssl \
                 wpad-mesh-openssl wpad-mesh-wolfssl wpad-mini \
                 wpad-openssl wpad-wolfssl-basic; do
    sed -i "/^CONFIG_PACKAGE_${wpad_var}=/d" .config 2>/dev/null
    echo "# CONFIG_PACKAGE_${wpad_var} is not set" >> .config
done

# 启用完整版 wpad-wolfssl（先删除已有配置，再添加）
sed -i "/^CONFIG_PACKAGE_wpad-wolfssl=/d" .config 2>/dev/null
sed -i "/^# CONFIG_PACKAGE_wpad-wolfssl is not set/d" .config 2>/dev/null
echo "CONFIG_PACKAGE_wpad-wolfssl=y" >> .config

# 禁用独立的 hostapd 和 wpa-supplicant
for pkg in hostapd hostapd-wolfssl hostapd-utils wpa-supplicant wpa-supplicant-wolfssl wpa-supplicant-basic; do
    sed -i "/^CONFIG_PACKAGE_${pkg}=/d" .config 2>/dev/null
    echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
done

echo "   ✓ Enabled wpad-wolfssl (Full version)"

# ============================================
# 2. 禁用不需要的包（frp, watchcat, kms等）
# ============================================
echo ""
echo "2. Disabling unnecessary packages..."

# frp 相关
for pkg in frp frpc frps luci-app-frp; do
    sed -i "/^CONFIG_PACKAGE_${pkg}=/d" .config 2>/dev/null
    echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
    echo "   ✓ Disabled PACKAGE_${pkg}"
done

# 其他不需要的包
for pkg in watchcat luci-app-watchcat vlmcsd luci-app-kms \
           NATMap luci-app-natmap xlnetacc wol; do
    sed -i "/^CONFIG_PACKAGE_${pkg}=/d" .config 2>/dev/null
    echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
    echo "   ✓ Disabled PACKAGE_${pkg}"
done

# ============================================
# 3. 确保 iptables 启用
# ============================================
echo ""
echo "3. Enabling iptables..."
sed -i "/^CONFIG_PACKAGE_iptables=/d" .config 2>/dev/null
sed -i "/^# CONFIG_PACKAGE_iptables is not set/d" .config 2>/dev/null
echo "CONFIG_PACKAGE_iptables=y" >> .config
echo "   ✓ Enabled PACKAGE_iptables"

# ============================================
# 4. CPU频率调节支持
# ============================================
echo ""
echo "4. Adding CPU frequency scaling support..."

# 内核选项
for opt in CPU_FREQ CPU_FREQ_GOV_CONSERVATIVE CPU_FREQ_GOV_ONDEMAND \
           CPU_FREQ_GOV_PERFORMANCE CPU_FREQ_GOV_POWERSAVE CPU_FREQ_GOV_USERSPACE \
           CPU_FREQ_DT PM_OPP; do
    sed -i "/^CONFIG_${opt}=/d" .config 2>/dev/null
    sed -i "/^# CONFIG_${opt} is not set/d" .config 2>/dev/null
    echo "CONFIG_${opt}=y" >> .config
done

# 内核模块包
for pkg in kmod-cpufreq-dt cpufreq luci-app-cpufreq; do
    sed -i "/^CONFIG_PACKAGE_${pkg}=/d" .config 2>/dev/null
    sed -i "/^# CONFIG_PACKAGE_${pkg} is not set/d" .config 2>/dev/null
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
done

echo "   ✓ Enabled CPU frequency scaling"

# ============================================
# 5. 写入额外的强制配置
# ============================================
echo ""
echo "5. Writing additional forced configs..."

cat >> .config << 'EOF'

# ========== 强制配置 ==========
CONFIG_PACKAGE_wpad-wolfssl=y
CONFIG_WPA_MULTI_BSSID=y
CONFIG_DRIVER_11N_SUPPORT=y
CONFIG_DRIVER_11AC_SUPPORT=y
CONFIG_DRIVER_11AX_SUPPORT=y
CONFIG_DRIVER_11R_SUPPORT=y
CONFIG_DRIVER_11K_SUPPORT=y
CONFIG_DRIVER_11V_SUPPORT=y
CONFIG_WPA_MBO_SUPPORT=y
CONFIG_WPA_SAE_SUPPORT=y
CONFIG_WPA_OWE_SUPPORT=y
EOF

# ============================================
# 6. 去重（删除重复的配置项，保留最后一个）
# ============================================
echo ""
echo "6. Deduplicating .config..."

# 使用 awk 去重：每个配置项只保留最后一次出现
awk '!seen[$1]++ {line[++count]=$0} END {for(i=1;i<=count;i++) print line[i]}' .config > .config.tmp
# 或者用 sort -u（简单但会打乱顺序）
sort -u .config > .config.tmp
mv .config.tmp .config

echo "   ✓ Removed duplicate entries"

# ============================================
# 7. 验证配置
# ============================================
echo ""
echo "=========================================="
echo "Configuration Summary:"
echo "=========================================="

if grep -q "^CONFIG_PACKAGE_wpad-wolfssl=y" .config; then
    echo "✅ wpad-wolfssl = y"
else
    echo "⚠️ wpad-wolfssl 未正确设置"
fi

if grep -q "^# CONFIG_PACKAGE_frp is not set" .config; then
    echo "✅ frp = n (disabled)"
elif grep -q "^CONFIG_PACKAGE_frp=y" .config; then
    echo "⚠️ frp = y (警告)"
fi

if grep -q "^CONFIG_PACKAGE_kmod-cpufreq-dt=y" .config; then
    echo "✅ kmod-cpufreq-dt = y"
fi

echo "=========================================="
echo ""
echo "✅ 配置完成！"
echo "=========================================="
