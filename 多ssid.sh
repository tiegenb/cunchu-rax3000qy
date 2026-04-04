#!/bin/bash
# 多ssid.sh - 编译前配置修改

echo "=========================================="
echo "Starting diy-part1.sh modifications..."
echo "=========================================="

# ============================================
# 1. 写入所有配置（一次性追加）
# ============================================
echo ""
echo "1. Writing configuration..."

cat >> .config << 'EOF'

# ========== wpad 完整版（支持多SSID） ==========
CONFIG_PACKAGE_wpad-wolfssl=y
# CONFIG_PACKAGE_wpad-basic-wolfssl is not set
# CONFIG_PACKAGE_wpad-mini is not set
# CONFIG_PACKAGE_wpad is not set
# CONFIG_PACKAGE_hostapd is not set
# CONFIG_PACKAGE_hostapd-wolfssl is not set
# CONFIG_PACKAGE_wpa-supplicant is not set
# CONFIG_PACKAGE_wpa-supplicant-wolfssl is not set

# ========== 多SSID 特性 ==========
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

# ========== 禁用不需要的包 ==========
# CONFIG_PACKAGE_frp is not set
# CONFIG_PACKAGE_frpc is not set
# CONFIG_PACKAGE_frps is not set
# CONFIG_PACKAGE_luci-app-frp is not set
# CONFIG_PACKAGE_watchcat is not set
# CONFIG_PACKAGE_luci-app-watchcat is not set
# CONFIG_PACKAGE_vlmcsd is not set
# CONFIG_PACKAGE_luci-app-kms is not set
# CONFIG_PACKAGE_NATMap is not set
# CONFIG_PACKAGE_luci-app-natmap is not set
# CONFIG_PACKAGE_xlnetacc is not set
# CONFIG_PACKAGE_wol is not set

# ========== CPU 频率调节 ==========
CONFIG_PACKAGE_kmod-cpufreq-dt=y
CONFIG_PACKAGE_cpufreq=y
CONFIG_PACKAGE_luci-app-cpufreq=y
CONFIG_CPU_FREQ=y
CONFIG_CPU_FREQ_GOV_ONDEMAND=y
CONFIG_CPU_FREQ_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_POWERSAVE=y

# ========== 其他 ==========
CONFIG_PACKAGE_iptables=y
EOF

echo "   ✓ Configuration written"

# ============================================
# 2. 去重
# ============================================
echo ""
echo "2. Deduplicating .config..."
if [ -f .config ]; then
    sort -u .config > .config.tmp && mv .config.tmp .config
    echo "   ✓ Removed duplicate entries"
else
    echo "   ⚠ .config not found, skipping"
fi

# ============================================
# 3. 验证配置
# ============================================
echo ""
echo "=========================================="
echo "Configuration Summary:"
echo "=========================================="

if grep -q "^CONFIG_PACKAGE_wpad-wolfssl=y" .config 2>/dev/null; then
    echo "✅ wpad-wolfssl = y (完整版，支持多SSID)"
else
    echo "⚠️ wpad-wolfssl 未正确设置"
fi

if grep -q "^# CONFIG_PACKAGE_frp is not set" .config 2>/dev/null; then
    echo "✅ frp = n (已禁用)"
elif grep -q "^CONFIG_PACKAGE_frp=y" .config 2>/dev/null; then
    echo "⚠️ frp = y (警告)"
fi

if grep -q "^CONFIG_PACKAGE_kmod-cpufreq-dt=y" .config 2>/dev/null; then
    echo "✅ CPU 频率调节 = y (已启用)"
fi

if grep -q "^CONFIG_WPA_MULTI_BSSID=y" .config 2>/dev/null; then
    echo "✅ 多SSID支持 = y (已启用)"
fi

echo "=========================================="
echo ""
echo "✅ 配置完成！"
echo "=========================================="
