#!/bin/bash
# 多ssid.sh - 编译前配置修改（简洁版）

echo "=========================================="
echo "Starting diy-part1.sh modifications..."
echo "=========================================="

# ============================================
# 1. 配置 wpad-wolfssl（完整版，支持多SSID）
# ============================================
echo ""
echo "1. Configuring wpad-wolfssl (Full version for Multi-SSID)..."

# 禁用所有其他 wpad 变体
for wpad_var in wpad wpad-basic wpad-basic-openssl wpad-basic-wolfssl \
                 wpad-mesh-openssl wpad-mesh-wolfssl wpad-mini \
                 wpad-openssl wpad-wolfssl-basic; do
    ./scripts/config --disable PACKAGE_${wpad_var} 2>/dev/null
done

# 启用完整版 wpad-wolfssl
./scripts/config --enable PACKAGE_wpad-wolfssl

# 禁用独立的 hostapd 和 wpa-supplicant
./scripts/config --disable PACKAGE_hostapd
./scripts/config --disable PACKAGE_hostapd-wolfssl
./scripts/config --disable PACKAGE_hostapd-utils
./scripts/config --disable PACKAGE_wpa-supplicant
./scripts/config --disable PACKAGE_wpa-supplicant-wolfssl
./scripts/config --disable PACKAGE_wpa-supplicant-basic

echo "   ✓ Enabled wpad-wolfssl (Full version)"

# ============================================
# 2. 禁用不需要的包（frp, watchcat, kms等）
# ============================================
echo ""
echo "2. Disabling unnecessary packages..."

# frp 相关
for pkg in frp frpc frps luci-app-frp; do
    ./scripts/config --disable PACKAGE_${pkg} 2>/dev/null
    echo "   ✓ Disabled PACKAGE_${pkg}"
done

# 其他不需要的包
for pkg in watchcat luci-app-watchcat vlmcsd luci-app-kms \
           NATMap luci-app-natmap xlnetacc wol; do
    ./scripts/config --disable PACKAGE_${pkg} 2>/dev/null
    echo "   ✓ Disabled PACKAGE_${pkg}"
done

# ============================================
# 3. 确保 iptables 启用
# ============================================
echo ""
echo "3. Enabling iptables..."
./scripts/config --enable PACKAGE_iptables
echo "   ✓ Enabled PACKAGE_iptables"

# ============================================
# 4. CPU频率调节支持
# ============================================
echo ""
echo "4. Adding CPU frequency scaling support..."

./scripts/config --enable CPU_FREQ
./scripts/config --enable CPU_FREQ_GOV_CONSERVATIVE
./scripts/config --enable CPU_FREQ_GOV_ONDEMAND
./scripts/config --enable CPU_FREQ_GOV_PERFORMANCE
./scripts/config --enable CPU_FREQ_GOV_POWERSAVE
./scripts/config --enable CPU_FREQ_GOV_USERSPACE
./scripts/config --enable CPUFREQ_DT
./scripts/config --enable PM_OPP
./scripts/config --enable PACKAGE_kmod-cpufreq-dt
./scripts/config --enable PACKAGE_cpufreq
./scripts/config --enable PACKAGE_luci-app-cpufreq

echo "   ✓ Enabled CPU frequency scaling"

# ============================================
# 5. 写入强制的 .config 覆盖（防止依赖拉回）
# ============================================
echo ""
echo "5. Writing forced config overrides..."

cat >> .config << 'EOF'

# ========== 强制禁用（防止依赖自动选中） ==========
# frp 系列
CONFIG_PACKAGE_frp=n
CONFIG_PACKAGE_frpc=n
CONFIG_PACKAGE_frps=n
CONFIG_PACKAGE_luci-app-frp=n

# watchcat
CONFIG_PACKAGE_watchcat=n
CONFIG_PACKAGE_luci-app-watchcat=n

# KMS
CONFIG_PACKAGE_vlmcsd=n
CONFIG_PACKAGE_luci-app-kms=n

# NATMap
CONFIG_PACKAGE_NATMap=n
CONFIG_PACKAGE_luci-app-natmap=n

# 其他
CONFIG_PACKAGE_xlnetacc=n
CONFIG_PACKAGE_wol=n

# wpad 完整版配置
CONFIG_PACKAGE_wpad-wolfssl=y
CONFIG_PACKAGE_wpad-basic-wolfssl=n

# 802.11 特性
CONFIG_DRIVER_11N_SUPPORT=y
CONFIG_DRIVER_11AC_SUPPORT=y
CONFIG_DRIVER_11AX_SUPPORT=y
CONFIG_DRIVER_11R_SUPPORT=y
CONFIG_DRIVER_11K_SUPPORT=y
CONFIG_DRIVER_11V_SUPPORT=y

# WPA3
CONFIG_WPA_MBO_SUPPORT=y
CONFIG_WPA_SAE_SUPPORT=y
CONFIG_WPA_OWE_SUPPORT=y
CONFIG_WPA_MULTI_BSSID=y
EOF

echo "   ✓ Forced config overrides written"

# ============================================
# 6. 验证配置
# ============================================
echo ""
echo "=========================================="
echo "Configuration Summary:"
echo "=========================================="

# 验证关键包状态
check_pkg() {
    if ./scripts/config --state $1 2>/dev/null | grep -q "y"; then
        echo "✅ $1 = y"
    elif ./scripts/config --state $1 2>/dev/null | grep -q "n"; then
        echo "❌ $1 = n"
    else
        echo "⚠️  $1 = undefined"
    fi
}

check_pkg PACKAGE_wpad-wolfssl
check_pkg PACKAGE_frp
check_pkg PACKAGE_frpc
check_pkg PACKAGE_watchcat
check_pkg PACKAGE_vlmcsd
check_pkg PACKAGE_NATMap
check_pkg PACKAGE_kmod-cpufreq-dt

echo "=========================================="
echo ""
echo "✅ 配置完成！"
echo "📌 现在可以运行: make download -j8 && make -j\$(nproc)"
echo "=========================================="
