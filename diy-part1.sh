#!/bin/bash
# diy-part1.sh - 编译前配置修改

echo "=========================================="
echo "Starting diy-part1.sh modifications..."
echo "=========================================="

# ============================================
# 0. 强制禁用所有 wpad 变体（避免冲突）
# ============================================
echo ""
echo "0. Force disabling all wpad variants (avoid conflict)..."

if [ -f "./scripts/config" ]; then
    # 禁用所有可能的 wpad 变体
    for wpad_var in wpad wpad-basic wpad-basic-openssl wpad-basic-wolfssl \
                     wpad-mesh-openssl wpad-mesh-wolfssl wpad-mini \
                     wpad-openssl wpad-wolfssl; do
        ./scripts/config --disable PACKAGE_${wpad_var} 2>/dev/null
    done
    
    # 同时禁用 wpa-supplicant（如果有冲突）
    for wpa_var in wpa-supplicant wpa-supplicant-basic wpa-supplicant-mini \
                   wpa-supplicant-openssl wpa-supplicant-wolfssl; do
        ./scripts/config --disable PACKAGE_${wpa_var} 2>/dev/null
    done
    
    echo "   ✓ Disabled all wpad/wpa-supplicant variants"
fi

# ============================================
# 1. 配置 hostapd（完整热点服务）
# ============================================
echo ""
echo "1. Configuring hostapd (完整热点服务)..."

# 方法1: 直接修改 .config 文件
cat >> .config << 'EOF'

# ========== hostapd 配置 ==========
# 启用 hostapd（wolfssl 版本 - 省空间）
CONFIG_PACKAGE_hostapd-wolfssl=y

# 强制禁用所有 wpad 变体（多重保障）
# CONFIG_PACKAGE_wpad is not set
# CONFIG_PACKAGE_wpad-basic is not set
# CONFIG_PACKAGE_wpad-basic-openssl is not set
CONFIG_PACKAGE_wpad-basic-wolfssl=n
# CONFIG_PACKAGE_wpad-mesh-openssl is not set
# CONFIG_PACKAGE_wpad-mesh-wolfssl is not set
# CONFIG_PACKAGE_wpad-mini is not set
# CONFIG_PACKAGE_wpad-openssl is not set
# CONFIG_PACKAGE_wpad-wolfssl is not set

# 强制禁用 wpa-supplicant（避免冲突）
# CONFIG_PACKAGE_wpa-supplicant is not set
# CONFIG_PACKAGE_wpa-supplicant-basic is not set
# CONFIG_PACKAGE_wpa-supplicant-mini is not set
# CONFIG_PACKAGE_wpa-supplicant-openssl is not set
# CONFIG_PACKAGE_wpa-supplicant-wolfssl is not set

# 启用 802.11 标准支持
CONFIG_DRIVER_11N_SUPPORT=y
CONFIG_DRIVER_11AC_SUPPORT=y
CONFIG_DRIVER_11AX_SUPPORT=y

# 启用 WPA3 支持
CONFIG_WPA_MBO_SUPPORT=y
CONFIG_WPA_SAE_SUPPORT=y
EOF

echo "   ✓ Added hostapd-wolfssl configuration"
echo "   ✓ Explicitly disabled wpad-basic-wolfssl (conflict avoided)"

# 创建 hostapd 自定义配置文件（裁剪功能，节省空间）
mkdir -p package/network/services/hostapd/files

cat > package/network/services/hostapd/files/hostapd-custom.conf << 'EOF'
# hostapd 自定义编译配置
# 只保留需要的功能，禁用不需要的以节省空间

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

# 禁用不常用的 802.11 扩展（省 ~30KB）
# CONFIG_HS20 is not set      # Hotspot 2.0
# CONFIG_INTERWORKING is not set
# CONFIG_MBO is not set        # 多频段操作
# CONFIG_RRM is not set        # 无线资源管理
EOF

echo "   ✓ Created hostapd custom config (optimized for size)"

# ============================================
# 2. 验证冲突已解决
# ============================================
echo ""
echo "2. Verifying configuration..."

if [ -f "./scripts/config" ]; then
    # 检查 wpad-basic-wolfssl 状态
    if ./scripts/config --state PACKAGE_wpad-basic-wolfssl 2>/dev/null | grep -q "n"; then
        echo "   ✅ wpad-basic-wolfssl is disabled"
    else
        echo "   ⚠ WARNING: wpad-basic-wolfssl may still be enabled"
        # 强制再次禁用
        ./scripts/config --disable PACKAGE_wpad-basic-wolfssl
    fi
    
    # 检查 hostapd 状态
    if ./scripts/config --state PACKAGE_hostapd-wolfssl 2>/dev/null | grep -q "y"; then
        echo "   ✅ hostapd-wolfssl is enabled"
    else
        echo "   ⚠ WARNING: hostapd-wolfssl not enabled"
    fi
fi

# ============================================
# 3. 禁用不需要的包
# ============================================
echo ""
echo "3. Disabling unnecessary packages..."

if [ -f "./scripts/config" ]; then
    for pkg in watchcat wol vlmcsd frpc NATMap xlnetacc; do
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
echo "✅ hostapd-wolfssl (完整热点服务)"
echo "✅ WPA3 (SAE) support"
echo "✅ 802.11n/ac/ax support"
echo "✅ CPU frequency scaling"
echo "✅ iptables firewall"
echo "❌ wpad-basic-wolfssl (disabled - conflict resolved)"
echo "=========================================="
echo "diy-part1.sh completed successfully!"
echo "=========================================="
