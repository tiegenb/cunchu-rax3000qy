#!/bin/bash
# diy-part1.sh

# 1. 禁用不需要的包
echo "Disabling unnecessary packages..."
for pkg in watchcat wol vlmcsd frpc NATMap xlnetacc; do
    ./scripts/config --disable PACKAGE_${pkg}
    echo "  - Disabled PACKAGE_${pkg}"
done

# 2. 确保 iptables 启用
./scripts/config --enable PACKAGE_iptables
echo "  - Enabled PACKAGE_iptables"

# 3. 可选：添加第三方包源
# sed -i '$a src-git mypackages https://github.com/xxx/xxx' feeds.conf.default

# ============================================
# 4. 添加CPU调节功能支持（不修改文件系统）
# ============================================
echo "Adding CPU frequency scaling support..."

# 启用内核CPU调频支持
./scripts/config --enable CONFIG_CPU_FREQ
./scripts/config --enable CONFIG_CPU_FREQ_GOV_CONSERVATIVE
./scripts/config --enable CONFIG_CPU_FREQ_GOV_ONDEMAND
./scripts/config --enable CONFIG_CPU_FREQ_GOV_PERFORMANCE
./scripts/config --enable CONFIG_CPU_FREQ_GOV_POWERSAVE
./scripts/config --enable CONFIG_CPU_FREQ_GOV_USERSPACE
./scripts/config --enable CONFIG_CPUFREQ_DT

# 启用CPU调节内核模块
./scripts/config --enable CONFIG_PACKAGE_kmod-cpufreq-dt

# 启用用户空间工具
./scripts/config --enable CONFIG_PACKAGE_cpufreq

# 启用Luci界面
./scripts/config --enable CONFIG_PACKAGE_luci-app-cpufreq

# 启用CPU亲和性工具
./scripts/config --enable CONFIG_PACKAGE_coreutils
./scripts/config --enable CONFIG_PACKAGE_coreutils-taskset

echo "  - Enabled kmod-cpufreq-dt"
echo "  - Enabled cpufreq"
echo "  - Enabled luci-app-cpufreq"
echo "  - Enabled coreutils-taskset"

echo "diy-part1.sh completed"
