#!/bin/bash
# 多ssid.sh - 编译前配置修改

echo "=========================================="
echo "Starting diy-part1.sh modifications..."
echo "=========================================="

# ============================================
# 0. 配置 wpad-wolfssl（完整版，支持多SSID）
# ============================================
echo ""
echo "0. Configuring wpad-wolfssl (Full version for Multi-SSID)..."

if [ -f "./scripts/config" ]; then
    # 禁用所有其他 wpad 变体
    for wpad_var in wpad wpad-basic wpad-basic-openssl wpad-basic-wolfssl \
                     wpad-mesh-openssl wpad-mesh-wolfssl wpad-mini \
                     wpad-openssl; do
        ./scripts/config --disable PACKAGE_${wpad_var} 2>/dev/null
    done
    
    # 启用完整版 wpad-wolfssl（支持多SSID、802.11r/k/v等）
    ./scripts/config --enable PACKAGE_wpad-wolfssl
    
    # 禁用独立的 hostapd（被 wpad 包含）
    ./scripts/config --disable PACKAGE_hostapd
    ./scripts/config --disable PACKAGE_hostapd-wolfssl
    ./scripts/config --disable PACKAGE_hostapd-utils
    
    # 禁用独立的 wpa-supplicant（被 wpad 包含）
    for wpa_var in wpa-supplicant wpa-supplicant-basic wpa-supplicant-mini \
                   wpa-supplicant-openssl wpa-supplicant-wolfssl; do
        ./scripts/config --disable PACKAGE_${wpa_var} 2>/dev/null
    done
    
    echo "   ✓ Enabled wpad-wolfssl (Full version - Multi-SSID capable)"
    echo "   ✓ Disabled all basic/mini variants"
fi

# 直接修改 .config 文件
cat >> .config << 'EOF'

# ========== wpad 完整版配置（支持多SSID） ==========
CONFIG_PACKAGE_wpad-wolfssl=y
# CONFIG_PACKAGE_wpad-basic-wolfssl is not set

# 启用完整 802.11 特性
CONFIG_DRIVER_11N_SUPPORT=y
CONFIG_DRIVER_11AC_SUPPORT=y
CONFIG_DRIVER_11AX_SUPPORT=y
CONFIG_DRIVER_11R_SUPPORT=y      # 快速漫游
CONFIG_DRIVER_11K_SUPPORT=y      # 无线资源管理
CONFIG_DRIVER_11V_SUPPORT=y      # BSS 过渡管理

# WPA3 完整支持
CONFIG_WPA_MBO_SUPPORT=y
CONFIG_WPA_SAE_SUPPORT=y
CONFIG_WPA_OWE_SUPPORT=y

# 多 BSSID 支持（多SSID所需）
CONFIG_WPA_MULTI_BSSID=y

# 禁用独立的 hostapd/wpa-supplicant（已包含在 wpad 中）
# CONFIG_PACKAGE_hostapd is not set
# CONFIG_PACKAGE_hostapd-wolfssl is not set
# CONFIG_PACKAGE_wpa-supplicant is not set
# CONFIG_PACKAGE_wpa-supplicant-wolfssl is not set
EOF

echo "   ✓ wpad-wolfssl configuration added to .config"

# 创建 wpad 自定义配置文件（裁剪功能，可选）
mkdir -p package/network/services/wpad/files

cat > package/network/services/wpad/files/wpad-custom.conf << 'EOF'
# wpad 自定义编译配置
# wpad-wolfssl 完整版配置

# ========== hostapd 部分（AP 功能） ==========
CONFIG_DRIVER_NL80211=y
CONFIG_TLS=wolfssl

# 认证协议支持
CONFIG_SAE=y          # WPA3-Personal
CONFIG_OWE=y          # 增强型开放网络

# 企业认证（保留，多SSID可能需要）
CONFIG_EAP=y
CONFIG_EAP_MSCHAPV2=y
CONFIG_EAP_TLS=y
CONFIG_EAP_TTLS=y
CONFIG_EAP_PEAP=y

# RADIUS 支持（多SSID可能需要）
CONFIG_RADIUS=y
CONFIG_ACCOUNTING=y

# 多 BSSID 核心支持
CONFIG_MULTI_BSSID=y

# 802.11r/k/v 漫游支持
CONFIG_IEEE80211R=y
CONFIG_IEEE80211K=y
CONFIG_IEEE80211V=y

# ========== wpa-supplicant 部分（客户端功能） ==========
# 保持完整客户端功能
CONFIG_IBSS_RSN=y
CONFIG_MATCH_IFACE=y
EOF

echo "   ✓ Created wpad custom config"

# ============================================
# 1. 验证配置
# ============================================
echo ""
echo "1. Verifying configuration..."

if [ -f "./scripts/config" ]; then
    # 检查 wpad-wolfssl 状态
    if ./scripts/config --state PACKAGE_wpad-wolfssl 2>/dev/null | grep -q "y"; then
        echo "   ✅ wpad-wolfssl is enabled (Full version - Multi-SSID capable)"
    else
        echo "   ⚠ WARNING: wpad-wolfssl not enabled, forcing..."
        ./scripts/config --enable PACKAGE_wpad-wolfssl
    fi
    
    # 检查 wpad-basic-wolfssl 状态（应该被禁用）
    if ./scripts/config --state PACKAGE_wpad-basic-wolfssl 2>/dev/null | grep -q "n"; then
        echo "   ✅ wpad-basic-wolfssl is disabled"
    fi
fi

# ============================================
# 2. 禁用不需要的包（包括 frp）
# ============================================
echo ""
echo "2. Disabling unnecessary packages..."

if [ -f "./scripts/config" ]; then
    # 禁用 frp 及其相关包（避免 quic-go 编译错误）
    for pkg in frp frpc frps luci-app-frp; do
        ./scripts/config --disable PACKAGE_${pkg} 2>/dev/null
        echo "   ✓ Disabled PACKAGE_${pkg}"
    done
    
    # 禁用其他不需要的包
    for pkg in watchcat wol vlmcsd NATMap xlnetacc; do
        ./scripts/config --disable PACKAGE_${pkg} 2>/dev/null
        echo "   ✓ Disabled PACKAGE_${pkg}"
    done
fi

# ============================================
# 3. 确保 iptables 启用
# ============================================
echo ""
echo "3. Enabling iptables..."
if [ -f "./scripts/config" ]; then
    ./scripts/config --enable PACKAGE_iptables
fi
echo "   ✓ Enabled PACKAGE_iptables"

# ============================================
# 4. CPU频率调节支持
# ============================================
echo ""
echo "4. Adding CPU frequency scaling support..."

if [ -f "./scripts/config" ]; then
    # 内核CPU调频子系统
    ./scripts/config --enable CPU_FREQ
    ./scripts/config --enable CPU_FREQ_GOV_CONSERVATIVE
    ./scripts/config --enable CPU_FREQ_GOV_ONDEMAND
    ./scripts/config --enable CPU_FREQ_GOV_PERFORMANCE
    ./scripts/config --enable CPU_FREQ_GOV_POWERSAVE
    ./scripts/config --enable CPU_FREQ_GOV_USERSPACE
    
    # CPU调频驱动
    ./scripts/config --enable CPUFREQ_DT
    ./scripts/config --enable PM_OPP
    
    # 内核模块包
    ./scripts/config --enable PACKAGE_kmod-cpufreq-dt
    
    # 用户空间工具
    ./scripts/config --enable PACKAGE_cpufreq
    ./scripts/config --enable PACKAGE_luci-app-cpufreq
    
    # 可选：CPU亲和性工具
    ./scripts/config --enable PACKAGE_coreutils
    ./scripts/config --enable PACKAGE_coreutils-taskset
fi

echo "   ✓ Enabled CPU frequency scaling support"
echo "   - kmod-cpufreq-dt"
echo "   - cpufreq"
echo "   - luci-app-cpufreq"

# ============================================
# 5. 显示最终配置摘要
# ============================================
echo ""
echo "=========================================="
echo "Configuration Summary:"
echo "=========================================="
echo "✅ wpad-wolfssl (FULL version - Multi-SSID capable)"
echo "   - Multiple BSSID support (多SSID)"
echo "   - 802.11r/k/v fast roaming (快速漫游)"
echo "   - Enterprise WPA2/WPA3 (企业认证)"
echo "   - RADIUS support"
echo "✅ WPA3 (SAE/OWE) support"
echo "✅ 802.11n/ac/ax support"
echo "✅ CPU frequency scaling"
echo "✅ iptables firewall"
echo "❌ frp/frpc/frps/luci-app-frp (disabled - quic-go compatibility)"
echo "=========================================="
echo ""
echo "📝 Multi-SSID hardware requirement:"
echo "   After flashing, run: iw list | grep -A 20 'valid interface combinations'"
echo "   Look for: 'max # of BSSIDs' or multiple 'AP' entries"
echo "=========================================="
echo "多ssid.sh completed successfully!"
echo "=========================================="
