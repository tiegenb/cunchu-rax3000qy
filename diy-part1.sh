#!/bin/bash
# diy-part1.sh - 编译前配置修改

echo "=========================================="
echo "Starting diy-part1.sh modifications..."
echo "=========================================="

# ============================================
# 0. 禁用其他 wpad 变体（保留 wpad-basic-wolfssl）
# ============================================
echo ""
echo "0. Disabling conflicting wpad variants..."

if [ -f "./scripts/config" ]; then
    # 禁用其他 wpad 变体（但不禁用 wpad-basic-wolfssl）
    for wpad_var in wpad wpad-basic wpad-basic-openssl \
                     wpad-mesh-openssl wpad-mesh-wolfssl wpad-mini \
                     wpad-openssl wpad-wolfssl; do
        ./scripts/config --disable PACKAGE_${wpad_var} 2>/dev/null
    done
    
    # 禁用 hostapd（wpad 会包含它）
    ./scripts/config --disable PACKAGE_hostapd 2>/dev/null
    ./scripts/config --disable PACKAGE_hostapd-wolfssl 2>/dev/null
    
    # 禁用 wpa-supplicant（wpad 会包含它）
    for wpa_var in wpa-supplicant wpa-supplicant-basic wpa-supplicant-mini \
                   wpa-supplicant-openssl wpa-supplicant-wolfssl; do
        ./scripts/config --disable PACKAGE_${wpa_var} 2>/dev/null
    done
    
    echo "   ✓ Disabled conflicting hostapd/wpa-supplicant variants"
fi

# ============================================
# 1. 配置 wpad-basic-wolfssl（AP + 客户端双模式）
# ============================================
echo ""
echo "1. Configuring wpad-basic-wolfssl (AP + Client dual mode)..."

# 直接修改 .config 文件
cat >> .config << 'EOF'

# ========== wpad 配置（双模式：AP + 客户端） ==========
# 启用 wpad-basic-wolfssl（包含 hostapd + wpa-supplicant）
CONFIG_PACKAGE_wpad-basic-wolfssl=y

# 确保其他 wpad 变体被禁用
# CONFIG_PACKAGE_wpad is not set
# CONFIG_PACKAGE_wpad-basic is not set
# CONFIG_PACKAGE_wpad-basic-openssl is not set
# CONFIG_PACKAGE_wpad-mesh-openssl is not set
# CONFIG_PACKAGE_wpad-mesh-wolfssl is not set
# CONFIG_PACKAGE_wpad-mini is not set
# CONFIG_PACKAGE_wpad-openssl is not set
# CONFIG_PACKAGE_wpad-wolfssl is not set

# 禁用独立的 hostapd（被 wpad 包含）
# CONFIG_PACKAGE_hostapd is not set
# CONFIG_PACKAGE_hostapd-wolfssl is not set

# 禁用独立的 wpa-supplicant（被 wpad 包含）
# CONFIG_PACKAGE_wpa-supplicant is not set
# CONFIG_PACKAGE_wpa-supplicant-wolfssl is not set

# 启用 802.11 标准支持
CONFIG_DRIVER_11N_SUPPORT=y
CONFIG_DRIVER_11AC_SUPPORT=y
CONFIG_DRIVER_11AX_SUPPORT=y

# 启用 WPA3 支持
CONFIG_WPA_MBO_SUPPORT=y
CONFIG_WPA_SAE_SUPPORT=y
EOF

echo "   ✓ Enabled wpad-basic-wolfssl (AP + Client support)"
echo "   ✓ Disabled hostapd-wolfssl (included in wpad)"
echo "   ✓ WPA3/SAE/MBO support enabled"

# 创建 wpad 自定义配置文件（裁剪功能，节省空间）
mkdir -p package/network/services/wpad/files

cat > package/network/services/wpad/files/wpad-custom.conf << 'EOF'
# wpad 自定义编译配置
# wpad-basic-wolfssl 包含 hostapd + wpa-supplicant
# 只保留需要的功能，禁用不需要的以节省空间

# ========== hostapd 部分（AP 功能） ==========
# 驱动支持
CONFIG_DRIVER_NL80211=y

# TLS 加密库（使用 wolfssl 省空间）
CONFIG_TLS=wolfssl

# 认证协议支持
CONFIG_SAE=y          # WPA3-Personal
CONFIG_OWE=y          # 增强型开放网络

# 禁用企业认证（省 ~100KB）
# CONFIG_EAP is not set
# CONFIG_EAP_AKA is not set
# CONFIG_EAP_FAST is not set
# CONFIG_EAP_GPSK is not set
# CONFIG_EAP_IKEV2 is not set
# CONFIG_EAP_MD5 is not set
# CONFIG_EAP_MSCHAPV2 is not set
# CONFIG_EAP_PAX is not set
# CONFIG_EAP_PSK is not set
# CONFIG_EAP_SAKE is not set
# CONFIG_EAP_SIM is not set
# CONFIG_EAP_TLS is not set
# CONFIG_EAP_TTLS is not set
# CONFIG_EAP_UNAUTH_TLS is not set
# CONFIG_EAP_WSC is not set

# 禁用 RADIUS（省 ~50KB）
# CONFIG_RADIUS is not set
# CONFIG_ACCOUNTING is not set

# 禁用 WEP（已不安全，省 ~20KB）
# CONFIG_WEP is not set

# ========== wpa-supplicant 部分（客户端功能） ==========
# 保持基础客户端功能可用
# 禁用不常用的扩展
# CONFIG_IBSS_RSN is not set
# CONFIG_MATCH_IFACE is not set
EOF

echo "   ✓ Created wpad custom config (optimized for size)"

# ============================================
# 2. 验证配置
# ============================================
echo ""
echo "2. Verifying configuration..."

if [ -f "./scripts/config" ]; then
    # 检查 wpad-basic-wolfssl 状态
    if ./scripts/config --state PACKAGE_wpad-basic-wolfssl 2>/dev/null | grep -q "y"; then
        echo "   ✅ wpad-basic-wolfssl is enabled (AP + Client)"
    else
        echo "   ⚠ WARNING: wpad-basic-wolfssl not enabled, forcing..."
        ./scripts/config --enable PACKAGE_wpad-basic-wolfssl
    fi
    
    # 检查 hostapd 状态（应该被禁用）
    if ./scripts/config --state PACKAGE_hostapd-wolfssl 2>/dev/null | grep -q "n"; then
        echo "   ✅ hostapd-wolfssl is disabled (included in wpad)"
    fi
fi

# ============================================
# 3. 禁用不需要的包（包括 frp）
# ============================================
echo ""
echo "3. Disabling unnecessary packages..."

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
# 4. 确保 iptables 启用
# ============================================
echo ""
echo "4. Enabling iptables..."
if [ -f "./scripts/config" ]; then
    ./scripts/config --enable PACKAGE_iptables
fi
echo "   ✓ Enabled PACKAGE_iptables"

# ============================================
# 5. CPU频率调节支持
# ============================================
echo ""
echo "5. Adding CPU frequency scaling support..."

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
# 6. 显示最终配置摘要
# ============================================
echo ""
echo "=========================================="
echo "Configuration Summary:"
echo "=========================================="
echo "✅ wpad-basic-wolfssl (AP + Client dual mode)"
echo "   - hostapd included (AP / hotspot)"
echo "   - wpa-supplicant included (client / connect to WiFi)"
echo "✅ WPA3 (SAE) support"
echo "✅ 802.11n/ac/ax support"
echo "✅ CPU frequency scaling"
echo "✅ iptables firewall"
echo "❌ frp/frpc/frps/luci-app-frp (disabled - quic-go compatibility)"
echo "=========================================="
echo "diy-part1.sh completed successfully!"
echo "=========================================="
